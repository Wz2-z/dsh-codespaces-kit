/**
 * dsh-sync-panel — Host half.
 *
 * 只做两件事：
 *   - `GET  /sync-panel/summary`  读 `.dsh-cloud/`（sync.conf、sync.sh --status、git、日志）
 *   - `POST /sync-panel/action`   代跑 `sync.sh --disable / --enable / --now / --mode=… / --squash-window=…`
 *
 * 两条都是 EXACT 路由，并且要求自定义请求头 `x-sync-panel: 1`：
 * 浏览器里的其它页面拿不到这个头，也就碰不到这些开关。
 * 这一半不碰 git 凭据、不碰 dsh 的 API Key，只是在本机跑仓库里的那个脚本。
 */
import { spawn } from 'node:child_process'
import { existsSync } from 'node:fs'
import { readdir, readFile } from 'node:fs/promises'
import { homedir } from 'node:os'
import { join } from 'node:path'

const FENCE_HEADER = 'x-sync-panel'
const ROUTE_PREFIX = '/sync-panel'
const DEFAULTS = { dir: '', workspace: '', timeoutMs: 60000, logLines: 8 }

export const name = 'sync-panel'
export const inject = ['webServer']

/** 记住上次找到的 .dsh-cloud，省得每次刷新都去扫 /workspaces。 */
let cachedDir = ''

export function apply(ctx, rawConfig) {
  const config = normalizeConfig(ctx, rawConfig)

  const mount = (path, action) =>
    ctx.effect(
      () =>
        ctx.webServer.register({
          kind: 'exact',
          path,
          handler: (req, res) => handle(ctx, config, action, req, res),
        }),
      `dsh-sync-panel: ${path}`,
    )

  mount(`${ROUTE_PREFIX}/summary`, 'summary')
  mount(`${ROUTE_PREFIX}/action`, 'action')
}

/** 手写校验（本插件不导出 Config 模式），typo 会记日志而不是静默生效。 */
function normalizeConfig(ctx, rawConfig) {
  const raw = rawConfig && typeof rawConfig === 'object' && !Array.isArray(rawConfig) ? rawConfig : {}
  const config = { ...DEFAULTS }
  for (const [key, value] of Object.entries(raw)) {
    if (!(key in DEFAULTS)) {
      ctx.logger?.warn?.('dsh-sync-panel: unknown config key "%s" ignored', key)
      continue
    }
    if (typeof DEFAULTS[key] === 'number') {
      const numeric = Number(value)
      if (Number.isFinite(numeric)) config[key] = numeric
      else ctx.logger?.warn?.('dsh-sync-panel: config "%s" must be a number', key)
    } else {
      config[key] = String(value)
    }
  }
  return config
}

/* ------------------------------------------------------------------ routing */

async function handle(ctx, config, action, req, res) {
  const site = String(req.headers['sec-fetch-site'] ?? '').toLowerCase()
  if (req.headers[FENCE_HEADER] !== '1' || site === 'cross-site') {
    sendJson(res, 403, { ok: false, error: { code: 'forbidden', message: '缺少插件请求头' } })
    return
  }
  const method = req.method ?? 'GET'
  try {
    if (action === 'summary') {
      if (method !== 'GET') {
        sendJson(res, 405, { ok: false, error: { code: 'method', message: 'summary 需要 GET' } })
        return
      }
      sendJson(res, 200, await buildSummary(config))
      return
    }
    if (method !== 'POST') {
      sendJson(res, 405, { ok: false, error: { code: 'method', message: 'action 需要 POST' } })
      return
    }
    const body = (await readJson(req)) ?? {}
    sendJson(res, 200, await runAction(config, body))
  } catch (error) {
    ctx.logger?.warn?.('dsh-sync-panel: %s', error?.message ?? String(error))
    sendJson(res, 200, {
      ok: false,
      error: { code: error?.code ?? 'internal', message: error?.message ?? String(error) },
    })
  }
}

async function buildSummary(config) {
  const dir = await resolveCloudDir(config)
  if (!dir) {
    return {
      ok: false,
      error: {
        code: 'no-sync-script',
        message: '没找到 .dsh-cloud/sync.sh（可以用配置项 dir 指定它的目录）',
      },
    }
  }
  const workspace = resolveWorkspace(config)
  const conf = parseConf(await readFile(join(dir, 'sync.conf'), 'utf8').catch(() => ''))
  const status = await run(['bash', join(dir, 'sync.sh'), '--status'], config.timeoutMs)
  const pending = await run(['git', '-C', workspace, 'status', '--porcelain', '-uall'], 15000)
  const last = await run(
    ['git', '-C', workspace, 'log', '-1', '--date=format:%m-%d %H:%M', '--format=%h %ad %s'],
    15000,
  )
  const pids = await daemonPids(dir)

  const pendingFiles = String(pending.out)
    .split('\n')
    .map((line) => line.slice(3).trim())
    .filter(Boolean)

  return {
    ok: true,
    data: {
      dir,
      workspace,
      conf,
      statusText: String(status.out).trim(),
      pendingCount: pendingFiles.length,
      pendingFiles: pendingFiles.slice(0, 6),
      lastCommit: String(last.out).trim(),
      daemon: pids.length > 0,
      daemonPids: pids,
      log: await tailLines(join(homedir(), 'dsh-sync.log'), config.logLines),
      now: new Date().toISOString(),
    },
  }
}

async function runAction(config, body) {
  const dir = await resolveCloudDir(config)
  if (!dir) return { ok: false, error: { code: 'no-sync-script', message: '没找到 .dsh-cloud/sync.sh' } }

  const action = String(body.action ?? '')
  const args = []
  if (action === 'pause') args.push('--disable')
  else if (action === 'resume') args.push('--enable')
  else if (action === 'now') args.push('--now')
  else if (action === 'mode') {
    const mode = String(body.mode ?? '')
    if (!['idle', 'interval', 'manual'].includes(mode)) {
      return { ok: false, error: { code: 'bad-mode', message: '模式只能是 idle / interval / manual' } }
    }
    args.push(`--mode=${mode}`)
    if (mode === 'interval' && Number.isFinite(Number(body.interval))) {
      args.push(`--interval=${Math.max(30, Number(body.interval))}`)
    }
  } else if (action === 'squash') {
    const seconds = Math.max(0, Number(body.squashWindow) || 0)
    args.push(`--squash-window=${seconds}`)
  } else {
    return { ok: false, error: { code: 'bad-action', message: `未知操作：${action}` } }
  }

  const result = await run(['bash', join(dir, 'sync.sh'), ...args], config.timeoutMs)
  const output = `${result.out}${result.err}`.trim()
  const summary = await buildSummary(config)
  return {
    ok: result.code === 0,
    data: { action, args, output, exitCode: result.code, summary: summary.ok ? summary.data : null },
    error: result.code === 0 ? undefined : { code: 'command-failed', message: output || `退出码 ${result.code}` },
  }
}

/* ----------------------------------------------------------------- helpers */

async function resolveCloudDir(config) {
  if (config.dir && existsSync(join(config.dir, 'sync.sh'))) return config.dir
  if (process.env.DSH_SYNC_DIR && existsSync(join(process.env.DSH_SYNC_DIR, 'sync.sh'))) {
    return process.env.DSH_SYNC_DIR
  }
  if (cachedDir && existsSync(join(cachedDir, 'sync.sh'))) return cachedDir
  try {
    for (const entry of await readdir('/workspaces', { withFileTypes: true })) {
      if (!entry.isDirectory()) continue
      const candidate = join('/workspaces', entry.name, '.dsh-cloud')
      if (existsSync(join(candidate, 'sync.sh'))) {
        cachedDir = candidate
        return candidate
      }
    }
  } catch {
    /* 不是 Codespaces，或者 /workspaces 不可读 */
  }
  return ''
}

function resolveWorkspace(config) {
  if (config.workspace) return config.workspace
  if (process.env.DSH_WORKSPACE) return process.env.DSH_WORKSPACE
  return join(homedir(), 'dsh-workspace')
}

function parseConf(text) {
  const conf = {}
  for (const line of String(text).split('\n')) {
    const trimmed = line.trim()
    if (trimmed === '' || trimmed.startsWith('#')) continue
    const eq = trimmed.indexOf('=')
    if (eq < 0) continue
    conf[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '')
  }
  return conf
}

async function tailLines(path, count) {
  try {
    const text = await readFile(path, 'utf8')
    return text.split('\n').filter((line) => line !== '').slice(-count)
  } catch {
    return []
  }
}

async function daemonPids(dir) {
  // 用括号写法避免 pgrep 匹配到自己这条命令
  const pattern = `${dir}/sync[.]sh`
  const result = await run(['bash', '-lc', `pgrep -f ${JSON.stringify(pattern)} || true`], 10000)
  return String(result.out)
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => /^\d+$/.test(line))
}

function run(args, timeoutMs) {
  return new Promise((resolve) => {
    let child
    try {
      child = spawn(args[0], args.slice(1), { env: process.env, cwd: homedir() })
    } catch (error) {
      resolve({ code: -1, out: '', err: String(error?.message ?? error) })
      return
    }
    let out = ''
    let err = ''
    const timer = setTimeout(() => {
      try {
        child.kill('SIGKILL')
      } catch {
        /* 已经退出了 */
      }
    }, Math.max(1000, timeoutMs))
    child.stdout?.on('data', (chunk) => {
      out += chunk
    })
    child.stderr?.on('data', (chunk) => {
      err += chunk
    })
    child.on('error', (error) => {
      clearTimeout(timer)
      resolve({ code: -1, out, err: `${err}${error?.message ?? error}` })
    })
    child.on('close', (code) => {
      clearTimeout(timer)
      resolve({ code: code ?? -1, out, err })
    })
  })
}

async function readJson(req) {
  const chunks = []
  let size = 0
  for await (const chunk of req) {
    size += chunk.length
    if (size > 64 * 1024) throw Object.assign(new Error('请求体过大'), { code: 'too-large' })
    chunks.push(chunk)
  }
  if (chunks.length === 0) return null
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'))
  } catch {
    throw Object.assign(new Error('请求体不是合法 JSON'), { code: 'bad-json' })
  }
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload)
  res.statusCode = status
  res.setHeader('content-type', 'application/json; charset=utf-8')
  res.setHeader('cache-control', 'no-store')
  res.end(body)
}
