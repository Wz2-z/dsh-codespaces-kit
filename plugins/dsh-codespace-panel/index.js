/**
 * dsh-codespace-panel — Host half.
 *
 * One row, four EXACT routes: the month's Codespaces quota (`/summary`,
 * `/token`) and this codespace's state and shutdown (`/codespace`, `/stop`).
 * The panel's own page reads them over the frame's HTTP server, so the browser
 * never holds a token and never talks to api.github.com cross-origin.
 *
 * Two deliberate choices, both learned the hard way:
 *
 * - EXACT routes only. The web server checks its exact table before its prefix
 *   table, and another plugin's row can still be mid-reload; an exact path that
 *   nobody else claims cannot collide with anything.
 * - No `Config` export. The row config is normalized here instead, so this
 *   plugin contributes nothing unusual to the profile's configurable-entry
 *   surface. (A loader row that fails to activate can break the config view
 *   every other plugin's settings form binds to, and a client plugin that binds
 *   its form once per session does not recover from that.)
 *
 * Two credentials, two scopes:
 * - The billing API needs a classic PAT with `user`, resolved in this order:
 *   row config `token`, `GITHUB_TOKEN`/`GH_TOKEN`/`CODESPACE_QUOTA_TOKEN`, the
 *   `codespace-panel/quota-token` record of the credential store, then — read
 *   only, for migration — the legacy plaintext `$DSH_HOME/codespace-quota.json`.
 *   Saving from the panel writes that credential record and deletes the legacy
 *   plaintext copy; this plugin never writes a secret to a file of its own.
 * - The Codespaces API accepts the container's own platform token, which the
 *   Codespaces agent writes into `/workspaces/.codespaces/shared/`; that token
 *   already carries the permission stopping needs, so shutdown works with no
 *   setup at all.
 */
import { readFile, rm, stat, statfs } from 'node:fs/promises'
import { cpus, homedir, loadavg, totalmem, uptime } from 'node:os'
import { join } from 'node:path'

const ROUTE_PREFIX = '/codespace-quota'
const FENCE_HEADER = 'x-codespace-quota'
const USER_AGENT = 'dsh-codespace-panel'

/** The container's own cgroup v2 root: the codespace's real memory/CPU/IO accounting. */
const CGROUP_ROOT = '/sys/fs/cgroup'

/** Files the Codespaces agent writes; both are readable by the codespace user. */
const AGENT_ENV_FILE = '/workspaces/.codespaces/shared/.env'
const AGENT_ENV_JSON = '/workspaces/.codespaces/shared/environment-variables.json'

/** Included monthly quota for personal accounts; compute is billed in core-hours. */
const PLAN_QUOTA = {
  free: { coreHours: 120, storageGb: 15 },
  pro: { coreHours: 180, storageGb: 20 },
}
const FALLBACK_QUOTA = PLAN_QUOTA.free

const DEFAULTS = {
  token: '',
  apiBase: 'https://api.github.com',
  /** 0 = derive from the account plan. */
  includedCoreHours: 0,
  includedStorageGb: 0,
  requestTimeoutMs: 15000,
  cacheSeconds: 120,
}

/** The one secret this plugin owns, addressed as `<scope>/<id>` in the credential store. */
const CREDENTIAL_KEY = 'codespace-panel/quota-token'

/** Legacy plaintext path: read for migration only, removed by the next save. */
const LEGACY_TOKEN_FILE = 'codespace-quota.json'

/** Token kept in process memory when the profile has no credential service. */
let sessionToken = ''

export const name = 'codespace-panel'
export const inject = ['webServer']

export function apply(ctx, rawConfig) {
  const config = normalizeConfig(ctx, rawConfig)
  const state = { cache: null, cacheAt: 0, inflight: null }

  const mount = (path, action) =>
    ctx.effect(
      () =>
        ctx.webServer.register({
          kind: 'exact',
          path,
          handler: (req, res) => handle(ctx, config, state, action, req, res),
        }),
      `dsh-codespace-panel: ${path}`,
    )

  mount(`${ROUTE_PREFIX}/summary`, 'summary')
  mount(`${ROUTE_PREFIX}/token`, 'token')
  mount(`${ROUTE_PREFIX}/codespace`, 'codespace')
  mount(`${ROUTE_PREFIX}/stop`, 'stop')
  mount(`${ROUTE_PREFIX}/resources`, 'resources')
}

/** Validate by hand (this plugin exports no Config schema) and report typos. */
function normalizeConfig(ctx, rawConfig) {
  const raw = rawConfig !== null && typeof rawConfig === 'object' && !Array.isArray(rawConfig) ? rawConfig : {}
  const config = { ...DEFAULTS }
  for (const [key, value] of Object.entries(raw)) {
    if (!(key in DEFAULTS)) {
      ctx.logger?.warn?.('dsh-codespace-panel: unknown config key "%s" ignored', key)
      continue
    }
    if (typeof DEFAULTS[key] === 'number') {
      const numeric = Number(value)
      if (Number.isFinite(numeric)) config[key] = numeric
      else ctx.logger?.warn?.('dsh-codespace-panel: config "%s" must be a number', key)
    } else {
      config[key] = String(value)
    }
  }
  return config
}

/* ------------------------------------------------------------------ routing */

const METHODS = { summary: 'GET', codespace: 'GET', token: 'POST', stop: 'POST', resources: 'GET' }

async function handle(ctx, config, state, action, req, res) {
  const site = String(req.headers['sec-fetch-site'] ?? '').toLowerCase()
  if (req.headers[FENCE_HEADER] !== '1' || site === 'cross-site') {
    sendJson(res, 403, { ok: false, error: { code: 'forbidden', message: '缺少插件请求头' } })
    return
  }
  const method = req.method ?? 'GET'
  if (method !== METHODS[action]) {
    sendJson(res, 405, { ok: false, error: { code: 'method', message: `${action} 需要 ${METHODS[action]}` } })
    return
  }
  try {
    sendJson(res, 200, await dispatch(ctx, config, state, action, req))
  } catch (error) {
    ctx.logger?.warn?.('dsh-codespace-panel: %s', error?.message ?? String(error))
    sendJson(res, 200, {
      ok: false,
      error: { code: error?.code ?? 'internal', message: error?.message ?? String(error), detail: error?.detail },
    })
  }
}

async function dispatch(ctx, config, state, action, req) {
  switch (action) {
    case 'summary':
      return summary(ctx, config, state)
    case 'token': {
      const body = await readJson(req)
      const token = typeof body?.token === 'string' ? body.token.trim() : ''
      const saved = await saveToken(ctx, token)
      const legacyRemoved = await removeLegacyTokenFile()
      state.cache = null
      return { ok: true, data: { saved: token !== '', hint: maskToken(token), ...saved, legacyRemoved } }
    }
    case 'codespace':
      return codespaceInfo(ctx, config)
    case 'resources':
      return collectResources()
    case 'stop':
      return stopCodespace(ctx, config)
    default:
      return { ok: false, error: { code: 'not-found', message: `未知动作 ${action}` } }
  }
}

/* ---------------------------------------------------------------- quota data */

/** Reuse one answer for `cacheSeconds`; failures are never cached. */
async function summary(ctx, config, state) {
  const ttl = Math.max(0, Number(config.cacheSeconds) || 0) * 1000
  if (state.cache !== null && Date.now() - state.cacheAt < ttl) return state.cache
  if (state.inflight !== null) return state.inflight
  state.inflight = (async () => {
    try {
      const payload = await collectQuota(ctx, config)
      if (payload.ok) {
        state.cache = payload
        state.cacheAt = Date.now()
      }
      return payload
    } finally {
      state.inflight = null
    }
  })()
  return state.inflight
}

async function collectQuota(ctx, config) {
  const credentials = await credentialsFor(ctx, config)
  if (credentials.tokens.length === 0) {
    return {
      ok: false,
      error: {
        code: 'no-token',
        message: '尚未配置 GitHub 令牌',
        detail: '在面板里粘贴一枚带 user 权限的经典 PAT，或设置 GITHUB_TOKEN 环境变量。',
      },
    }
  }

  const account = await call(config, credentials, 'GET', '/user')
  const login = String(account?.login ?? '')
  if (login === '') throw quotaError('unexpected', 'GitHub /user 未返回登录名')

  const plan = String(account?.plan?.name ?? 'unknown').toLowerCase()
  const now = new Date()
  const year = now.getFullYear()
  const month = now.getMonth() + 1

  const probes = [
    `/users/${encodeURIComponent(login)}/settings/billing/usage?year=${year}&month=${month}`,
    `/users/${encodeURIComponent(login)}/settings/billing/usage/summary?year=${year}&month=${month}`,
  ]
  let usage = null
  let source = ''
  let lastError = null
  for (const path of probes) {
    try {
      usage = await call(config, credentials, 'GET', path)
      source = path.includes('/summary') ? 'billing-usage-summary' : 'billing-usage'
      break
    } catch (error) {
      lastError = error
      if (error?.code === 'auth' || error?.code === 'forbidden') throw error
    }
  }
  if (usage === null) throw lastError ?? quotaError('unexpected', 'GitHub 账单接口没有返回数据')

  const items = collectUsageItems(usage)
  const totals = { coreHours: 0, storage: 0, other: [] }
  const codespaces = []
  for (const item of items) {
    const product = String(item.product ?? '')
    const sku = String(item.sku ?? '')
    const haystack = `${product} ${sku}`.toLowerCase()
    const record = {
      product,
      sku,
      unitType: String(item.unitType ?? item.unit_type ?? ''),
      quantity: numberOrZero(item.quantity),
      price: numberOrZero(item.pricePerUnit ?? item.price_per_unit),
    }
    if (!haystack.includes('codespace')) {
      if (record.quantity > 0) totals.other.push(record)
      continue
    }
    codespaces.push(record)
    const unit = record.unitType.toLowerCase()
    if (unit.includes('hour')) totals.coreHours += record.quantity
    else if (unit.includes('gigabyte') || unit === 'gb' || unit.includes('gb-')) totals.storage += record.quantity
    else if (unit.includes('byte')) totals.storage += record.quantity / 1024 ** 3
    else totals.other.push(record)
  }

  const included = includedQuota(config, plan)
  return {
    ok: true,
    data: {
      login,
      plan,
      planLabel: planLabel(plan),
      period: billingPeriod(now),
      compute: {
        used: round(totals.coreHours),
        included: included.coreHours,
        remaining: included.coreHours > 0 ? round(Math.max(0, included.coreHours - totals.coreHours)) : null,
        percent: percentOf(totals.coreHours, included.coreHours),
        unit: '核心·小时',
      },
      storage: {
        used: round(totals.storage),
        included: included.storageGb,
        remaining: included.storageGb > 0 ? round(Math.max(0, included.storageGb - totals.storage)) : null,
        percent: percentOf(totals.storage, included.storageGb),
        unit: 'GB·月',
      },
      items: codespaces,
      otherItems: totals.other.slice(0, 12),
      quotaAssumed: included.assumed,
      tokenSource: credentials.quotaSource,
      tokenHint: maskToken(credentials.quotaToken),
      legacyPlaintext: credentials.legacyPlaintext,
      source,
      fetchedAt: new Date().toISOString(),
    },
  }
}

/** Codespaces usage arrives in `usageItems`; both API generations nest it differently. */
function collectUsageItems(node, out = [], depth = 0) {
  if (depth > 8 || node === null || typeof node !== 'object') return out
  if (Array.isArray(node)) {
    for (const entry of node) {
      if (isUsageItem(entry)) out.push(entry)
      else collectUsageItems(entry, out, depth + 1)
    }
    return out
  }
  for (const value of Object.values(node)) collectUsageItems(value, out, depth + 1)
  return out
}

function isUsageItem(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false
  if (!('quantity' in value)) return false
  return 'product' in value || 'sku' in value || 'unitType' in value || 'unit_type' in value
}

function includedQuota(config, plan) {
  const known = PLAN_QUOTA[plan] ?? null
  const fallback = known ?? FALLBACK_QUOTA
  return {
    coreHours: Number(config.includedCoreHours) > 0 ? Number(config.includedCoreHours) : fallback.coreHours,
    storageGb: Number(config.includedStorageGb) > 0 ? Number(config.includedStorageGb) : fallback.storageGb,
    assumed: known === null,
  }
}

/** Included compute resets at the start of each monthly billing cycle. */
function billingPeriod(now) {
  const year = now.getFullYear()
  const month = now.getMonth()
  const start = new Date(year, month, 1)
  const end = new Date(year, month + 1, 1)
  return {
    year,
    month: month + 1,
    label: `${year}-${String(month + 1).padStart(2, '0')}`,
    startsAt: isoDate(start),
    resetsAt: isoDate(end),
    daysLeft: Math.max(1, Math.round((end - now) / 86400000)),
  }
}

/* ------------------------------------------------------------ codespace data */

async function codespaceInfo(ctx, config) {
  const credentials = await credentialsFor(ctx, config)
  const name = credentials.codespaceName
  if (name === '') throw quotaError('no-codespace', '无法识别当前 Codespace（缺少 CODESPACE_NAME）')
  const body = await call(config, credentials, 'GET', `/user/codespaces/${encodeURIComponent(name)}`)
  const codespace = body ?? {}
  return {
    ok: true,
    data: {
      name: String(codespace.name ?? name),
      displayName: String(codespace.display_name ?? ''),
      state: String(codespace.state ?? ''),
      stateLabel: stateLabel(codespace.state),
      running: codespace.state === 'Available',
      machine: String(codespace.machine?.display_name ?? ''),
      repository: String(codespace.repository?.full_name ?? ''),
      idleTimeoutMinutes: numberOrNull(codespace.idle_timeout_minutes),
      lastUsedAt: String(codespace.last_used_at ?? ''),
      createdAt: String(codespace.created_at ?? ''),
      pendingOperation: codespace.pending_operation === true,
      webUrl: String(codespace.web_url ?? ''),
      credentials: credentials.codespaceSource,
      fetchedAt: new Date().toISOString(),
    },
  }
}

/** Ask GitHub to shut this codespace down; the answer lands before the socket dies. */
async function stopCodespace(ctx, config) {
  const credentials = await credentialsFor(ctx, config)
  const name = credentials.codespaceName
  if (name === '') throw quotaError('no-codespace', '无法识别当前 Codespace（缺少 CODESPACE_NAME）')
  await call(config, credentials, 'POST', `/user/codespaces/${encodeURIComponent(name)}/stop`)
  return { ok: true, data: { name, state: 'Shutdown', requestedAt: new Date().toISOString() } }
}

/* ------------------------------------------------------------- hardware use */

/**
 * Live hardware use of this codespace. Everything is read from the container's
 * own cgroup v2 and its filesystems, so the numbers describe the codespace, not
 * the host machine behind it, and no API call or token is involved.
 */
async function collectResources() {
  const [memory, cpu, disk, pressure] = await Promise.all([sampleMemory(), sampleCpu(), sampleDisk(), samplePressure()])
  return {
    ok: true,
    data: {
      sampledAt: new Date().toISOString(),
      cores: cpus().length,
      memory,
      cpu,
      disk,
      pressure,
      processes: await readNumber(`${CGROUP_ROOT}/pids.current`),
      uptimeSeconds: Math.round(uptime()),
    },
  }
}

/** Container memory: `memory.current` is the codespace's real footprint. */
async function sampleMemory() {
  const [current, max, peak, meminfo] = await Promise.all([
    readNumber(`${CGROUP_ROOT}/memory.current`),
    readText(`${CGROUP_ROOT}/memory.max`),
    readNumber(`${CGROUP_ROOT}/memory.peak`),
    readText('/proc/meminfo'),
  ])
  const info = parseMeminfo(meminfo)
  const machineBytes = info.total ?? totalmem()
  const limitBytes = max !== null && max.trim() !== 'max' ? Number(max.trim()) : null
  const usedBytes =
    current ?? (info.total !== undefined && info.available !== undefined ? info.total - info.available : null)
  const totalBytes = limitBytes ?? machineBytes
  return {
    usedBytes,
    totalBytes,
    machineBytes,
    peakBytes: peak,
    limitBytes,
    percent: usedBytes !== null && totalBytes > 0 ? round1((usedBytes / totalBytes) * 100) : null,
    source: current !== null ? 'cgroup' : 'proc',
  }
}

/** CPU use over a short window, as a share of the whole machine (cores × 100%). */
async function sampleCpu() {
  const cores = cpus().length || 1
  const first = await cpuUsageUsec()
  if (first === null) {
    const [oneMinute] = loadavg()
    return { percent: round1((oneMinute / cores) * 100), cores, loadAverage: loadavg(), source: 'loadavg' }
  }
  const startedAt = Date.now()
  await delay(250)
  const second = (await cpuUsageUsec()) ?? first
  const elapsedMs = Math.max(1, Date.now() - startedAt)
  const busyMs = (second - first) / 1000
  return {
    percent: round1((busyMs / (elapsedMs * cores)) * 100),
    cores,
    loadAverage: loadavg(),
    source: 'cgroup',
  }
}

/** The volume the workspace lives on (the machine's storage), in bytes. */
async function sampleDisk() {
  for (const mount of ['/workspaces', '/']) {
    try {
      const stats = await statfs(mount)
      const totalBytes = stats.blocks * stats.bsize
      const freeBytes = stats.bavail * stats.bsize
      const usedBytes = totalBytes - freeBytes
      return {
        mount,
        totalBytes,
        freeBytes,
        usedBytes,
        percent: totalBytes > 0 ? round1((usedBytes / totalBytes) * 100) : null,
      }
    } catch {
      /* try the next mount */
    }
  }
  return null
}

/** PSI stall averages: how much work is waiting on CPU or memory, not how busy they are. */
async function samplePressure() {
  const [cpu, memory] = await Promise.all([
    readText(`${CGROUP_ROOT}/cpu.pressure`),
    readText(`${CGROUP_ROOT}/memory.pressure`),
  ])
  return { cpu: parsePsiAvg60(cpu), memory: parsePsiAvg60(memory) }
}

function parsePsiAvg60(text) {
  if (text === null) return null
  const match = /some\s+avg10=[\d.]+\s+avg60=([\d.]+)/.exec(text)
  return match === null ? null : Number(match[1])
}

function parseMeminfo(text) {
  if (text === null) return {}
  const read = (key) => {
    const match = new RegExp(`^${key}:\\s+(\\d+)\\s+kB`, 'm').exec(text)
    return match === null ? undefined : Number(match[1]) * 1024
  }
  return { total: read('MemTotal'), available: read('MemAvailable') }
}

async function cpuUsageUsec() {
  const text = await readText(`${CGROUP_ROOT}/cpu.stat`)
  if (text === null) return null
  const match = /^usage_usec\s+(\d+)/m.exec(text)
  return match === null ? null : Number(match[1])
}

async function readText(file) {
  try {
    return await readFile(file, 'utf8')
  } catch {
    return null
  }
}

async function readNumber(file) {
  const text = await readText(file)
  if (text === null) return null
  const value = Number(text.trim().split(/\s+/)[0])
  return Number.isFinite(value) ? value : null
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

/* --------------------------------------------------------------- credentials */

function legacyTokenPath() {
  const home = process.env.DSH_HOME && process.env.DSH_HOME !== '' ? process.env.DSH_HOME : join(homedir(), '.dsh')
  return join(home, LEGACY_TOKEN_FILE)
}

/** The legacy plaintext file, read only to migrate an older install. */
async function readLegacyToken() {
  try {
    const parsed = JSON.parse(await readFile(legacyTokenPath(), 'utf8'))
    return typeof parsed?.token === 'string' ? parsed.token.trim() : ''
  } catch {
    return ''
  }
}

/** This plugin's own credential record; '' when unset or when no store exists. */
async function readSavedToken(ctx) {
  const credentials = ctx.get?.('credentials')
  if (credentials === undefined) return ''
  try {
    const record = await credentials.readRecord(CREDENTIAL_KEY)
    if (record === undefined) return ''
    if (record.kind === 'api-key') return String(record.key ?? '').trim()
    return String(record.payload?.token ?? '').trim()
  } catch (error) {
    ctx.logger?.warn?.('dsh-codespace-panel: 读取凭据记录失败：%s', error?.message ?? String(error))
    return ''
  }
}

/**
 * Persist the billing token in the credential store — `$DSH_HOME/.credentials.yaml`
 * (0600), shared with every other plugin's secrets, and never a file of our own.
 * A profile without the credential service keeps it in process memory and says so
 * instead of writing plaintext.
 */
async function saveToken(ctx, token) {
  const credentials = ctx.get?.('credentials')
  if (credentials === undefined) {
    sessionToken = token
    return { persisted: false }
  }
  if (token === '') await credentials.deleteRecord(CREDENTIAL_KEY)
  else await credentials.modifyRecord(CREDENTIAL_KEY, async () => ({ kind: 'api-key', key: token }))
  // With a store there is no second copy to keep: the document is the record.
  sessionToken = ''
  return { persisted: true }
}

/** Rotating or clearing the token retires the legacy plaintext copy with it. */
async function removeLegacyTokenFile() {
  try {
    await stat(legacyTokenPath())
  } catch {
    return false
  }
  try {
    await rm(legacyTokenPath(), { force: true })
    return true
  } catch {
    return false
  }
}

/**
 * Candidate credentials in the order they are tried. A rejected credential falls
 * through to the next, so the platform token serves the Codespaces API while the
 * billing PAT serves quota. Row config and environment variables outrank the
 * stored record, so a rotated `GITHUB_TOKEN` takes effect without a restart.
 */
async function credentialsFor(ctx, config) {
  const agentEnv = await readAgentEnv()
  const codespaceName =
    firstNonEmpty([process.env.CODESPACE_NAME, agentEnv.CODESPACE_NAME]) || (await codespaceNameFromJson())
  const configured = String(config.token ?? '').trim()
  const envToken = firstNonEmpty([process.env.GITHUB_TOKEN, process.env.GH_TOKEN, process.env.CODESPACE_QUOTA_TOKEN])
  const saved = (await readSavedToken(ctx)) || sessionToken
  const legacy = await readLegacyToken()
  const platformToken = firstNonEmpty([agentEnv.GITHUB_TOKEN, agentEnv.GITHUB_CODESPACE_TOKEN, process.env.GITHUB_TOKEN])

  const tokens = []
  const push = (value, source) => {
    const token = String(value ?? '').trim()
    if (token !== '' && !tokens.some((entry) => entry.token === token)) tokens.push({ token, source })
  }
  push(configured, 'config')
  push(envToken, 'env')
  push(saved, 'stored')
  push(legacy, 'legacy-file')
  push(platformToken, 'codespace')

  const quotaToken = firstNonEmpty([configured, envToken, saved, legacy])
  const quotaSource =
    configured !== '' ? 'config' : envToken !== '' ? 'env' : saved !== '' ? 'stored' : legacy !== '' ? 'legacy-file' : 'none'
  const codespaceSource = platformToken !== '' ? 'codespace' : tokens[0]?.source ?? 'none'
  return { codespaceName, tokens, quotaToken, quotaSource, codespaceSource, legacyPlaintext: legacy !== '' }
}

async function codespaceNameFromJson() {
  try {
    const parsed = JSON.parse(await readFile(AGENT_ENV_JSON, 'utf8'))
    return firstNonEmpty([parsed?.CODESPACE_NAME])
  } catch {
    return ''
  }
}

/** `KEY=value` lines, tolerant of quotes, `export`, CRLF and comments. */
async function readAgentEnv() {
  const values = {}
  try {
    const text = await readFile(AGENT_ENV_FILE, 'utf8')
    for (const rawLine of text.split('\n')) {
      const line = rawLine.trim().replace(/^export\s+/, '')
      if (line === '' || line.startsWith('#')) continue
      const separator = line.indexOf('=')
      if (separator <= 0) continue
      const key = line.slice(0, separator).trim()
      let value = line.slice(separator + 1).trim()
      if (
        (value.startsWith('"') && value.endsWith('"') && value.length > 1) ||
        (value.startsWith("'") && value.endsWith("'") && value.length > 1)
      ) {
        value = value.slice(1, -1)
      }
      values[key] = value
    }
  } catch {
    /* not a codespace, or the file is unreadable: callers fall back */
  }
  return values
}

function maskToken(token) {
  if (token === undefined || token === null || token === '') return ''
  return `${String(token).slice(0, 4)}…${String(token).slice(-4)}`
}

/* ---------------------------------------------------------------- API access */

async function call(config, credentials, method, path) {
  if (credentials.tokens.length === 0) throw quotaError('no-token', '没有可用的 GitHub 凭据')
  let lastError = null
  for (const candidate of credentials.tokens) {
    try {
      return await request(config, candidate.token, method, path)
    } catch (error) {
      if (error?.code !== 'auth' && error?.code !== 'forbidden') throw error
      lastError = error
    }
  }
  throw lastError ?? quotaError('auth', 'GitHub 拒绝了所有可用凭据')
}

async function request(config, token, method, path) {
  const apiBase = String(config.apiBase || DEFAULTS.apiBase).replace(/\/+$/, '')
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), Math.max(1000, Number(config.requestTimeoutMs) || 15000))
  let response
  try {
    response = await fetch(`${apiBase}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${token}`,
        accept: 'application/vnd.github+json',
        'x-github-api-version': '2022-11-28',
        'user-agent': USER_AGENT,
      },
      signal: controller.signal,
    })
  } catch (error) {
    if (error?.name === 'AbortError') throw quotaError('timeout', 'GitHub API 请求超时')
    throw quotaError('network', `无法访问 GitHub API：${error?.message ?? String(error)}`)
  } finally {
    clearTimeout(timer)
  }

  const text = await response.text()
  let body = null
  try {
    body = text === '' ? null : JSON.parse(text)
  } catch {
    body = null
  }
  if (response.ok) return body

  const detail = typeof body?.message === 'string' ? body.message : `HTTP ${response.status}`
  if (response.status === 401) throw quotaError('auth', '令牌无效或已过期', detail)
  if (response.status === 403) throw quotaError('forbidden', '权限不足或已触发限流（账单接口需要经典 PAT 的 user 权限）', detail)
  if (response.status === 404) throw quotaError('not-found', '找不到该资源（Codespace 可能已被删除）', detail)
  if (response.status === 409) throw quotaError('conflict', '该 Codespace 正在执行其它操作，请稍后再试', detail)
  if (response.status === 422) throw quotaError('invalid', 'GitHub 拒绝了这次请求', detail)
  throw quotaError('http', `GitHub API 返回 ${response.status}`, detail)
}

/* ----------------------------------------------------------------- plumbing */

async function readJson(req) {
  const chunks = []
  let size = 0
  for await (const chunk of req) {
    size += chunk.length
    if (size > 64 * 1024) throw quotaError('too-large', '请求体过大')
    chunks.push(chunk)
  }
  if (chunks.length === 0) return null
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'))
  } catch {
    throw quotaError('bad-json', '请求体不是合法 JSON')
  }
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload)
  res.statusCode = status
  res.setHeader('content-type', 'application/json; charset=utf-8')
  res.setHeader('cache-control', 'no-store')
  res.end(body)
}

function quotaError(code, message, detail) {
  const error = new Error(message)
  error.code = code
  if (detail !== undefined) error.detail = detail
  return error
}

function firstNonEmpty(values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim() !== '') return value.trim()
  }
  return ''
}

function numberOrZero(value) {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : 0
}

function numberOrNull(value) {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

function round(value) {
  return Math.round(value * 100) / 100
}

function round1(value) {
  return Math.round(value * 10) / 10
}

function percentOf(used, included) {
  if (!(included > 0)) return null
  return Math.round((used / included) * 1000) / 10
}

function planLabel(plan) {
  if (plan === 'free') return 'Free'
  if (plan === 'pro') return 'Pro'
  if (plan === 'unknown' || plan === '') return '未知套餐'
  return plan
}

function stateLabel(state) {
  switch (state) {
    case 'Available':
      return '运行中'
    case 'Shutdown':
      return '已停止'
    case 'Starting':
      return '启动中'
    case 'ShuttingDown':
      return '正在停止'
    case 'Queued':
      return '排队中'
    case 'Creating':
      return '创建中'
    case 'Deleted':
      return '已删除'
    case 'Unavailable':
      return '不可用'
    case 'Moved':
      return '已迁移'
    case 'Failed':
      return '失败'
    default:
      return state === '' ? '未知' : state
  }
}

function isoDate(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}
