/**
 * dsh-codespace-panel — Client half.
 *
 * Two slot entries share one module-level store:
 *   - `sidebar.footer.action`  the compact trigger beside Settings;
 *   - `shell.overlay`          the pop-up panel, which must live in the
 *                              frame-wide layer so no column can clip it.
 * All numbers come from the Host half over `/codespace-quota/*`, so this module
 * never talks to GitHub and never holds a token.
 *
 * Keep `sidebar.footer.action` entries cheap and unconditional: the footer is a
 * shared seat, and other occupants (`dsh-remote-web-ui`, `dsh-cost-meter`) wrap
 * it in their own layout CSS, so an entry that grows or disappears on state
 * change moves their controls too.
 */
window.__ModuleLoader__.load({
  id: 'dsh-codespace-panel',
  factory(require) {
    const React = require('react')
    const h = React.createElement

    const NS = 'codespace-quota'
    const ROUTE = '/codespace-quota'
    const FENCE = { 'x-codespace-quota': '1' }
    const AUTO_REFRESH_MS = 5 * 60 * 1000

    /* ------------------------------------------------------------ dictionary */

    const zh = {
      trigger: 'Codespaces 额度',
      title: 'Codespaces 额度',
      refresh: '刷新',
      close: '关闭',
      loading: '正在读取额度…',
      retry: '重试',
      compute: '计算额度',
      storage: '存储额度',
      used: '已用',
      remaining: '剩余',
      included: '含',
      unlimited: '不限',
      resets: '{label} 周期 · {date} 重置（还剩 {days} 天）',
      updated: '更新于 {time}',
      source: '数据源 {source}',
      planAssumed: '套餐未识别，按 Free 额度估算',
      details: '原始用量明细',
      noTokenTitle: '尚未配置 GitHub 令牌',
      noTokenBody: '账单接口需要一枚 GitHub 经典 PAT（勾选 user 权限）。保存后写入 DSH 凭据存储（~/.dsh/.credentials.yaml，0600），不会再落明文文件；也可以直接设置 GITHUB_TOKEN 环境变量。',
      tokenPlaceholder: '粘贴 ghp_… 或 github_pat_…',
      save: '保存',
      saving: '保存中…',
      savedHint: '当前令牌 {hint}（来源：{source}）',
      memoryOnly: '这个 profile 没有凭据服务，令牌只在本次运行内有效；重启前请设置 GITHUB_TOKEN 环境变量。',
      legacyWarn: '检测到旧的明文令牌文件 ~/.dsh/codespace-quota.json：保存一次新令牌会自动删除它，建议同时在 GitHub 吊销旧令牌。',
      savedMigrated: '已保存到凭据存储，并删除了旧的明文令牌文件。',
      clear: '清除',
      createToken: '打开 GitHub 令牌设置页',
      tokenHint: '提示：细粒度令牌不支持个人账单接口，请用经典 PAT。',
      errorFallback: '读取失败',
      errorNoToken: '尚未配置 GitHub 令牌',
      detail: '详情',
      csTitle: '当前 Codespace',
      csLoading: '正在读取 Codespace 状态…',
      csRetry: '重试',
      csOpen: '在 GitHub 打开',
      csIdle: '空闲 {minutes} 分钟后自动停止',
      csLastUsed: '上次使用 {time}',
      csRepo: '仓库 {repo}',
      csStop: '停止 Codespace',
      csStopWhy: '停止后这个页面会断开，DSH 也会停止；额度同时停止累计。',
      csConfirm: '确定停止 {name}？',
      csCancel: '取消',
      csConfirmYes: '确认停止',
      csStopping: '正在停止…',
      csStopped: '已发送停止请求，Codespace 正在关闭；如果这个页面直接断开，说明已经停止。',
      csPending: '有其它操作正在进行，暂时不能停止',
      csFailed: '停止失败',
      csUnavailable: '读不到 Codespace 状态',
      hwTitle: '硬件使用',
      hwMemory: '内存',
      hwCpu: 'CPU',
      hwDisk: '磁盘',
      hwCores: '{cores} 核',
      hwLoad: '负载 {a} / {b} / {c}',
      hwProcesses: '进程 {count}',
      hwUptime: '系统运行 {hours}',
      hwPressure: '资源竞争 CPU {cpu}% · 内存 {mem}%',
      hwSampling: '正在采样…',
      hwFailed: '读取失败',
      hwNeedRestart: '硬件采样需要重启一次 dsh 后才生效（Host 代码缓存在运行进程里）',
      hwPeak: '峰值 {value}',
      hwFree: '可用 {value}',
      hwHours: '{hours} 小时',
      hwMinutes: '{minutes} 分钟',
    }

    const en = {
      trigger: 'Codespaces quota',
      title: 'Codespaces quota',
      refresh: 'Refresh',
      close: 'Close',
      loading: 'Reading quota…',
      retry: 'Retry',
      compute: 'Compute',
      storage: 'Storage',
      used: 'used',
      remaining: 'left',
      included: 'of',
      unlimited: 'unlimited',
      resets: '{label} period · resets {date} ({days} days left)',
      updated: 'Updated {time}',
      source: 'Source {source}',
      planAssumed: 'Unknown plan — assuming Free allowance',
      details: 'Raw usage items',
      noTokenTitle: 'No GitHub token yet',
      noTokenBody: 'The billing API needs a GitHub classic PAT with the `user` scope. Saving writes it to the DSH credential store (~/.dsh/.credentials.yaml, 0600) — never to a plaintext file of its own. You can also just set GITHUB_TOKEN.',
      tokenPlaceholder: 'paste ghp_… or github_pat_…',
      save: 'Save',
      saving: 'Saving…',
      savedHint: 'Token {hint} (source: {source})',
      memoryOnly: 'This profile has no credential service, so the token lasts only for this run. Set GITHUB_TOKEN before restarting.',
      legacyWarn: 'Legacy plaintext token file ~/.dsh/codespace-quota.json found: saving a new token deletes it, and the old token should be revoked on GitHub.',
      savedMigrated: 'Saved to the credential store and deleted the legacy plaintext file.',
      clear: 'Clear',
      createToken: 'Open GitHub token settings',
      tokenHint: 'Fine-grained tokens do not cover personal billing endpoints — use a classic PAT.',
      errorFallback: 'Request failed',
      errorNoToken: 'No GitHub token yet',
      detail: 'Detail',
      csTitle: 'This Codespace',
      csLoading: 'Reading codespace state…',
      csRetry: 'Retry',
      csOpen: 'Open on GitHub',
      csIdle: 'Stops after {minutes} idle minutes',
      csLastUsed: 'Last used {time}',
      csRepo: 'Repo {repo}',
      csStop: 'Stop Codespace',
      csStopWhy: 'Stopping disconnects this page and shuts Harness down; quota stops accruing at the same moment.',
      csConfirm: 'Stop {name}?',
      csCancel: 'Cancel',
      csConfirmYes: 'Stop it',
      csStopping: 'Stopping…',
      csStopped: 'Stop request accepted; the codespace is shutting down. If this page disconnects, it worked.',
      csPending: 'Another operation is in progress — stopping is unavailable right now',
      csFailed: 'Stop failed',
      csUnavailable: 'Cannot read codespace state',
      hwTitle: 'Hardware',
      hwMemory: 'Memory',
      hwCpu: 'CPU',
      hwDisk: 'Disk',
      hwCores: '{cores} cores',
      hwLoad: 'load {a} / {b} / {c}',
      hwProcesses: '{count} processes',
      hwUptime: 'up {hours}',
      hwPressure: 'contention CPU {cpu}% · memory {mem}%',
      hwSampling: 'Sampling…',
      hwFailed: 'Read failed',
      hwNeedRestart: 'Hardware sampling needs one dsh restart (Host code is cached in the running process)',
      hwPeak: 'peak {value}',
      hwFree: '{value} free',
      hwHours: '{hours} h',
      hwMinutes: '{minutes} min',
    }

    /* ----------------------------------------------------------------- style */

    const CSS = `
.csq-trigger{display:inline-flex;align-items:center;justify-content:center;gap:6px;height:32px;min-width:32px;padding:0 6px;border:0;border-radius:8px;background:transparent;color:var(--dsw-alias-label-secondary);cursor:pointer;font:inherit;font-size:12px;line-height:1;position:relative}
.csq-trigger:hover{background:var(--dsw-alias-bg-layer-2);color:var(--dsw-alias-label-primary)}
.csq-trigger[aria-expanded="true"]{background:var(--dsw-alias-bg-layer-2);color:var(--dsw-alias-label-primary)}
.csq-trigger:focus-visible{outline:2px solid var(--dsw-alias-brand-primary);outline-offset:2px}
.csq-trigger svg{display:block}
.csq-num{font-size:12px;line-height:1;font-variant-numeric:tabular-nums;white-space:nowrap}
.csq-dot{position:absolute;top:4px;right:4px;width:6px;height:6px;border-radius:50%;background:var(--dsw-alias-state-idle-primary)}
.csq-dot[data-state="ok"]{background:var(--dsw-alias-state-success-primary)}
.csq-dot[data-state="warn"]{background:var(--dsw-alias-state-warn-primary)}
.csq-dot[data-state="error"]{background:var(--dsw-alias-state-error-primary)}
.csq-backdrop{position:fixed;inset:0;pointer-events:auto;background:transparent;z-index:1}
.csq-panel{position:fixed;left:12px;bottom:60px;z-index:2;width:min(340px,calc(100vw - 24px));box-sizing:border-box;pointer-events:auto;background:var(--dsw-alias-bg-overlay);color:var(--dsw-alias-label-primary);border:1px solid var(--dsw-alias-border-l2);border-radius:12px;font-family:inherit;font-size:13px;line-height:1.5;box-shadow:0 10px 28px -12px color-mix(in oklab,var(--dsw-alias-label-primary) 45%,transparent);overflow:hidden}
.csq-head{display:flex;align-items:center;gap:8px;padding:10px 12px;border-bottom:1px solid var(--dsw-alias-border-l1)}
.csq-head h2{margin:0;font-size:13px;font-weight:600;flex:1 1 auto;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.csq-iconbtn{display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;border:0;border-radius:6px;background:transparent;color:var(--dsw-alias-label-secondary);cursor:pointer;font:inherit}
.csq-iconbtn:hover{background:var(--dsw-alias-bg-layer-2);color:var(--dsw-alias-label-primary)}
.csq-iconbtn:disabled{opacity:.5;cursor:default}
.csq-body{padding:12px}
.csq-sub{display:flex;align-items:center;gap:8px;margin-bottom:10px;font-size:12px;color:var(--dsw-alias-label-secondary)}
.csq-badge{padding:1px 6px;border-radius:999px;border:1px solid var(--dsw-alias-border-l1);font-size:11px}
.csq-metric{margin-bottom:12px}
.csq-metric:last-child{margin-bottom:0}
.csq-metric-head{display:flex;align-items:baseline;gap:6px;font-size:12px;color:var(--dsw-alias-label-secondary)}
.csq-metric-head b{color:var(--dsw-alias-label-primary);font-size:14px;font-weight:600}
.csq-spacer{flex:1 1 auto}
.csq-track{position:relative;height:6px;margin-top:6px;border-radius:999px;background:var(--dsw-alias-bg-layer-2);overflow:hidden}
.csq-fill{position:absolute;inset:0 auto 0 0;border-radius:999px;background:var(--dsw-alias-state-success-primary)}
.csq-fill[data-level="warn"]{background:var(--dsw-alias-state-warn-primary)}
.csq-fill[data-level="error"]{background:var(--dsw-alias-state-error-primary)}
.csq-note{margin-top:10px;font-size:11px;line-height:1.6;color:var(--dsw-alias-label-secondary)}
.csq-note code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px}
.csq-row{display:flex;align-items:center;gap:6px;margin-top:8px}
.csq-input{flex:1 1 auto;min-width:0;height:30px;padding:0 8px;box-sizing:border-box;border:1px solid var(--dsw-alias-border-l2);border-radius:8px;background:var(--dsw-alias-bg-layer-1);color:var(--dsw-alias-label-primary);font:inherit;font-size:12px}
.csq-input:focus{outline:none;border-color:var(--dsw-alias-brand-primary)}
.csq-btn{height:30px;padding:0 12px;border:1px solid var(--dsw-alias-border-l2);border-radius:8px;background:var(--dsw-alias-bg-layer-2);color:var(--dsw-alias-label-primary);cursor:pointer;font:inherit;font-size:12px;white-space:nowrap}
.csq-btn:hover{border-color:var(--dsw-alias-brand-primary)}
.csq-btn:disabled{opacity:.5;cursor:default}
.csq-btn-primary{background:var(--dsw-alias-brand-primary);border-color:var(--dsw-alias-brand-primary);color:var(--dsw-alias-bg-base)}
.csq-link{color:var(--dsw-alias-brand-primary);text-decoration:none;font-size:12px}
.csq-link:hover{text-decoration:underline}
.csq-error{color:var(--dsw-alias-state-error-primary);font-size:12px}
.csq-warn{color:var(--dsw-alias-state-warn-primary);font-size:12px}
.csq-items{margin-top:8px;max-height:150px;overflow:auto;border-top:1px solid var(--dsw-alias-border-l1);padding-top:8px}
.csq-item{display:flex;gap:8px;font-size:11px;color:var(--dsw-alias-label-secondary);font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
.csq-item span:last-child{margin-left:auto;color:var(--dsw-alias-label-primary)}
.csq-sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.csq-section{margin-top:12px;padding-top:10px;border-top:1px solid var(--dsw-alias-border-l1)}
.csq-mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;overflow-wrap:anywhere}
.csq-line{display:flex;gap:6px;font-size:11px;line-height:1.7;color:var(--dsw-alias-label-secondary)}
.csq-line b{font-weight:500;color:var(--dsw-alias-label-primary)}
.csq-btn-danger{background:var(--dsw-alias-state-error-primary);border-color:var(--dsw-alias-state-error-primary);color:var(--dsw-alias-bg-base)}
.csq-btn-danger:hover{border-color:var(--dsw-alias-state-error-primary);opacity:.9}
.csq-confirm{margin-top:8px;padding:8px;border:1px solid var(--dsw-alias-state-error-primary);border-radius:8px}
.csq-ok{color:var(--dsw-alias-state-success-primary);font-size:12px}
.csq-spark{display:block;width:100%;height:26px;margin:2px 0 6px;border-radius:4px;background:var(--dsw-alias-bg-layer-2)}
.csq-hw-row{display:flex;align-items:baseline;gap:6px;font-size:11px;line-height:1.7;color:var(--dsw-alias-label-secondary)}
.csq-hw-row b{font-weight:500;color:var(--dsw-alias-label-primary);font-variant-numeric:tabular-nums}
.csq-hw-name{flex:none;width:3.2em}
.csq-hw-bar{flex:1 1 auto;min-width:40px;position:relative;height:6px;border-radius:999px;background:var(--dsw-alias-bg-layer-2);overflow:hidden;align-self:center}
.csq-hw-pct{flex:none;min-width:3.2em;text-align:right;font-variant-numeric:tabular-nums}
.csq-hw-note{margin-top:6px;font-size:11px;line-height:1.6;color:var(--dsw-alias-label-secondary)}
`

    function installStyle() {
      const element = document.createElement('style')
      element.setAttribute('data-dsh-plugin', NS)
      element.textContent = CSS
      document.head.appendChild(element)
      return () => {
        element.remove()
      }
    }

    /* ----------------------------------------------------------------- state */

    /** Stable method identities: the subscription hooks depend on them. */
    function createStore(initial) {
      let snapshot = initial
      const listeners = new Set()
      return {
        subscribe: (listener) => {
          listeners.add(listener)
          return () => listeners.delete(listener)
        },
        getSnapshot: () => snapshot,
        set: (next) => {
          snapshot = { ...snapshot, ...next }
          for (const listener of [...listeners]) {
            try {
              listener()
            } catch {
              /* a broken subscriber must not break the store */
            }
          }
        },
      }
    }

    const uiStore = createStore({ open: false })
    const dataStore = createStore({ status: 'idle', value: null, error: null, at: 0 })

    let inflight = null

    async function request(method, path, body) {
      const response = await fetch(`${ROUTE}${path}`, {
        method,
        credentials: 'same-origin',
        headers: body === undefined ? FENCE : { ...FENCE, 'content-type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
      })
      // A path the running Host does not serve yet falls through to the SPA shell,
      // which answers HTML: report that as an unrouted call, not as bad JSON.
      if (!String(response.headers.get('content-type') ?? '').includes('json')) {
        throw Object.assign(new Error(`HTTP ${response.status}`), { code: 'not-json', status: response.status })
      }
      const payload = await response.json().catch(() => null)
      if (payload === null || typeof payload !== 'object') {
        throw Object.assign(new Error(`HTTP ${response.status}`), { code: 'http', status: response.status })
      }
      return payload
    }

    function load(options) {
      const force = options?.force === true
      if (inflight !== null) return inflight
      dataStore.set({ status: dataStore.getSnapshot().value === null ? 'loading' : 'refreshing', error: null })
      inflight = (async () => {
        try {
          const payload = await request('GET', force ? '/summary?refresh=1' : '/summary')
          if (payload.ok === true) dataStore.set({ status: 'ready', value: payload.data, error: null, at: Date.now() })
          else dataStore.set({ status: 'error', error: payload.error ?? { code: 'unknown' }, at: Date.now() })
        } catch (error) {
          dataStore.set({
            status: 'error',
            error: { code: error?.code ?? 'network', message: error?.message ?? String(error) },
            at: Date.now(),
          })
        } finally {
          inflight = null
        }
      })()
      return inflight
    }

    async function saveToken(token) {
      const payload = await request('POST', '/token', { token })
      if (payload.ok !== true) throw Object.assign(new Error(payload.error?.message ?? 'save failed'), payload.error ?? {})
      await load({ force: true })
      return payload.data ?? {}
    }

    /* --------------------------------------------- codespace state and control */

    const csStore = createStore({ status: 'idle', value: null, error: null, at: 0 })
    let csInflight = null

    function loadCodespace() {
      if (csInflight !== null) return csInflight
      csStore.set({ status: csStore.getSnapshot().value === null ? 'loading' : 'refreshing', error: null })
      csInflight = (async () => {
        try {
          const payload = await request('GET', '/codespace')
          if (payload.ok === true) csStore.set({ status: 'ready', value: payload.data, error: null, at: Date.now() })
          else csStore.set({ status: 'error', error: payload.error ?? { code: 'unknown' }, at: Date.now() })
        } catch (error) {
          csStore.set({
            status: 'error',
            error: { code: error?.code ?? 'network', message: error?.message ?? String(error) },
            at: Date.now(),
          })
        } finally {
          csInflight = null
        }
      })()
      return csInflight
    }

    async function stopCodespace() {
      return request('POST', '/stop')
    }

    /* ------------------------------------------------------- hardware sampling */

    /** ~4 minutes of history at the 5s poll: enough to see a build spike. */
    const HISTORY_LIMIT = 48
    const RESOURCES_REFRESH_MS = 5000

    const resStore = createStore({
      status: 'idle',
      value: null,
      error: null,
      at: 0,
      history: { cpu: [], memory: [] },
    })
    let resInflight = null

    function loadResources() {
      if (resInflight !== null) return resInflight
      const before = resStore.getSnapshot()
      resStore.set({ status: before.value === null ? 'loading' : 'refreshing', error: null })
      resInflight = (async () => {
        try {
          const payload = await request('GET', '/resources')
          if (payload.ok === true) {
            const push = (series, next) => [...series, next].slice(-HISTORY_LIMIT)
            resStore.set({
              status: 'ready',
              value: payload.data,
              error: null,
              at: Date.now(),
              history: {
                cpu: push(before.history.cpu, payload.data.cpu?.percent ?? 0),
                memory: push(before.history.memory, payload.data.memory?.percent ?? 0),
              },
            })
          } else {
            resStore.set({ status: 'error', error: payload.error ?? { code: 'unknown' }, at: Date.now() })
          }
        } catch (error) {
          resStore.set({
            status: 'error',
            error: { code: error?.code ?? 'network', message: error?.message ?? String(error), status: error?.status },
            at: Date.now(),
          })
        } finally {
          resInflight = null
        }
      })()
      return resInflight
    }

    function formatBytes(bytes) {
      if (typeof bytes !== 'number' || !Number.isFinite(bytes) || bytes < 0) return '—'
      const gb = bytes / 1024 ** 3
      return gb >= 1 ? `${gb.toFixed(1)} GB` : `${Math.round(bytes / 1024 ** 2)} MB`
    }

    function formatUptime(t, seconds) {
      if (typeof seconds !== 'number' || !Number.isFinite(seconds)) return '—'
      return seconds >= 3600
        ? t('hwHours', { hours: (seconds / 3600).toFixed(1) })
        : t('hwMinutes', { minutes: Math.max(1, Math.round(seconds / 60)) })
    }

    /** Chosen once: a React without `useSyncExternalStore` falls back to a state bump. */
    const hasSyncExternalStore = typeof React.useSyncExternalStore === 'function'

    function useSubscribed(subscribe, getSnapshot) {
      if (hasSyncExternalStore) return React.useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
      const [, bump] = React.useState(0)
      React.useEffect(() => subscribe(() => bump((value) => value + 1)), [subscribe])
      return getSnapshot()
    }

    function useStore(store) {
      return useSubscribed(store.subscribe, store.getSnapshot)
    }

    function useTranslate(ctx) {
      const locale = ctx.locale
      const subscribe = React.useCallback(
        (listener) => {
          try {
            return locale.subscribe(listener)
          } catch {
            return () => {}
          }
        },
        [locale],
      )
      const read = React.useCallback(() => {
        try {
          return String(locale.getSnapshot()?.active ?? 'en')
        } catch {
          return 'en'
        }
      }, [locale])
      const active = useSubscribed(subscribe, read)
      const lang = active.toLowerCase().startsWith('zh') ? 'zh' : 'en'
      return React.useCallback(
        (key, params) => {
          const dict = lang === 'zh' ? zh : en
          const template = dict[key] ?? en[key] ?? key
          if (params === undefined) return template
          return template.replace(/\{(\w+)\}/g, (match, name) =>
            params[name] === undefined ? match : String(params[name]),
          )
        },
        [lang],
      )
    }

    /* ------------------------------------------------------------- components */

    function Icon(props) {
      return h(
        'svg',
        { viewBox: '0 0 20 20', width: props?.size ?? 16, height: props?.size ?? 16, 'aria-hidden': 'true', focusable: 'false' },
        h('rect', {
          x: 1.6, y: 5.6, width: 14, height: 8.8, rx: 2.6,
          fill: 'none', stroke: 'currentColor', strokeWidth: 1.5,
        }),
        h('rect', {
          x: 3.9, y: 7.9, width: props?.fill ?? 5.4, height: 4.2, rx: 1.3,
          fill: 'currentColor',
        }),
        h('path', { d: 'M17.6 8.6v2.8', stroke: 'currentColor', strokeWidth: 1.5, strokeLinecap: 'round' }),
      )
    }

    function levelOf(percent) {
      if (percent === null || percent === undefined) return 'ok'
      if (percent >= 90) return 'error'
      if (percent >= 70) return 'warn'
      return 'ok'
    }

    function fillWidth(percent) {
      if (percent === null || percent === undefined) return 0
      return Math.max(0, Math.min(100, percent))
    }

    function Metric(props) {
      const t = props.t
      const percent = props.percent
      return h(
        'div',
        { className: 'csq-metric' },
        h(
          'div',
          { className: 'csq-metric-head' },
          h('span', null, props.label),
          h('b', null, `${props.used}`),
          h('span', null, `${t('included')} ${props.included} ${props.unit}`),
          h('span', { className: 'csq-spacer' }),
          h('span', null, percent === null ? '—' : `${percent}%`),
        ),
        h(
          'div',
          { className: 'csq-track' },
          h('div', { className: 'csq-fill', 'data-level': levelOf(percent), style: { width: `${fillWidth(percent)}%` } }),
        ),
        h(
          'div',
          { className: 'csq-metric-head', style: { marginTop: 6 } },
          h('span', null, t('remaining')),
          h('b', null, props.remaining === null ? '—' : `${props.remaining}`),
          h('span', null, props.unit),
        ),
      )
    }

    function TokenForm(props) {
      const t = props.t
      const [draft, setDraft] = React.useState('')
      const [busy, setBusy] = React.useState(false)
      const [message, setMessage] = React.useState(null)
      const submit = () => {
        if (busy || draft.trim() === '') return
        setBusy(true)
        setMessage(null)
        saveToken(draft.trim())
          .then((data) => {
            setDraft('')
            const text =
              data.persisted === false ? t('memoryOnly') : data.legacyRemoved === true ? t('savedMigrated') : t('save')
            setMessage({ kind: 'ok', text })
          })
          .catch((error) => setMessage({ kind: 'error', text: error?.message ?? String(error) }))
          .finally(() => setBusy(false))
      }
      return h(
        'div',
        null,
        h('div', { className: 'csq-note', style: { marginTop: 0, marginBottom: 8 } }, t('noTokenBody')),
        h(
          'div',
          { className: 'csq-row' },
          h('input', {
            className: 'csq-input',
            type: 'password',
            value: draft,
            spellCheck: false,
            autoComplete: 'off',
            placeholder: t('tokenPlaceholder'),
            'aria-label': t('tokenPlaceholder'),
            onChange: (event) => setDraft(event.target.value),
            onKeyDown: (event) => {
              if (event.key === 'Enter') submit()
            },
          }),
          h(
            'button',
            { type: 'button', className: 'csq-btn csq-btn-primary', disabled: busy || draft.trim() === '', onClick: submit },
            busy ? t('saving') : t('save'),
          ),
        ),
        message === null
          ? null
          : h('div', { className: message.kind === 'error' ? 'csq-error' : 'csq-note', style: { marginTop: 6 } }, message.text),
        h(
          'div',
          { className: 'csq-note' },
          h(
            'a',
            {
              className: 'csq-link',
              href: 'https://github.com/settings/tokens/new?scopes=user&description=DSH%20Codespaces%20quota',
              target: '_blank',
              rel: 'noreferrer noopener',
            },
            t('createToken'),
          ),
          h('div', null, t('tokenHint')),
        ),
      )
    }

    function Detail(props) {
      const t = props.t
      const value = props.value
      const items = [...(value.items ?? []), ...(value.otherItems ?? [])]
      if (items.length === 0) return null
      return h(
        'details',
        null,
        h('summary', { className: 'csq-note', style: { cursor: 'pointer' } }, t('details')),
        h(
          'div',
          { className: 'csq-items' },
          items.map((item, index) =>
            h(
              'div',
              { className: 'csq-item', key: `${item.sku}-${index}` },
              h('span', null, item.sku === '' ? item.product : item.sku),
              h('span', null, item.unitType),
              h('span', null, String(item.quantity)),
            ),
          ),
        ),
      )
    }

    /**
     * This codespace's live hardware use: memory and CPU from its own cgroup,
     * disk from the workspace volume. Sampling needs Host code the running
     * process may not have loaded yet, so an unrouted call says exactly that.
     */
    function ResourcesSection(props) {
      const t = props.t
      const snapshot = useStore(resStore)
      const value = snapshot.value

      const header = (right) =>
        h(
          'div',
          { className: 'csq-sub', style: { marginBottom: 6 } },
          h('span', null, t('hwTitle')),
          h('span', { className: 'csq-spacer' }),
          right ?? null,
        )

      if (value === null) {
        const error = snapshot.error ?? {}
        const unrouted = error.code === 'not-json' || error.status === 404
        return h(
          'div',
          { className: 'csq-section' },
          header(null),
          unrouted
            ? h('div', { className: 'csq-warn' }, t('hwNeedRestart'))
            : snapshot.status === 'error'
              ? h('div', { className: 'csq-error' }, error.message ?? t('hwFailed'))
              : h('div', { className: 'csq-line' }, t('hwSampling')),
        )
      }

      const memory = value.memory ?? {}
      const cpu = value.cpu ?? {}
      const disk = value.disk
      const rows = [
        {
          label: t('hwMemory'),
          percent: memory.percent,
          detail: `${formatBytes(memory.usedBytes)} / ${formatBytes(memory.totalBytes)}`,
        },
        {
          label: t('hwCpu'),
          percent: cpu.percent,
          detail: t('hwCores', { cores: cpu.cores ?? value.cores ?? '?' }),
        },
        disk === null || disk === undefined
          ? null
          : {
              label: t('hwDisk'),
              percent: disk.percent,
              detail: `${formatBytes(disk.usedBytes)} / ${formatBytes(disk.totalBytes)}`,
            },
      ].filter(Boolean)

      const extras = []
      if (memory.peakBytes) extras.push(t('hwPeak', { value: formatBytes(memory.peakBytes) }))
      if (Array.isArray(cpu.loadAverage) && cpu.loadAverage.length >= 3) {
        extras.push(
          t('hwLoad', {
            a: cpu.loadAverage[0].toFixed(2),
            b: cpu.loadAverage[1].toFixed(2),
            c: cpu.loadAverage[2].toFixed(2),
          }),
        )
      }
      if (disk !== null && disk !== undefined) extras.push(t('hwFree', { value: formatBytes(disk.freeBytes) }))
      if (value.processes !== null && value.processes !== undefined) {
        extras.push(t('hwProcesses', { count: value.processes }))
      }
      extras.push(t('hwUptime', { hours: formatUptime(t, value.uptimeSeconds) }))
      const pressure = value.pressure ?? {}
      const contended = (pressure.cpu ?? 0) >= 10 || (pressure.memory ?? 0) >= 10

      return h(
        'div',
        { className: 'csq-section' },
        header(null),
        h(Sparkline, {
          series: [
            { points: snapshot.history.memory, color: 'var(--dsw-alias-state-success-primary)' },
            { points: snapshot.history.cpu, color: 'var(--dsw-alias-brand-primary)' },
          ],
        }),
        rows.map((row) =>
          h(
            'div',
            { className: 'csq-hw-row', key: row.label },
            h('span', { className: 'csq-hw-name' }, row.label),
            h('b', null, row.detail),
            h(
              'span',
              { className: 'csq-hw-bar' },
              h('span', {
                className: 'csq-fill',
                'data-level': levelOf(row.percent),
                style: { width: `${fillWidth(row.percent)}%` },
              }),
            ),
            h('span', { className: 'csq-hw-pct' }, row.percent === null || row.percent === undefined ? '—' : `${row.percent}%`),
          ),
        ),
        h('div', { className: 'csq-hw-note' }, extras.join(' · ')),
        contended
          ? h(
              'div',
              { className: 'csq-warn' },
              t('hwPressure', { cpu: pressure.cpu ?? 0, mem: pressure.memory ?? 0 }),
            )
          : null,
      )
    }

    /** Two-polyline history strip: memory above, CPU below, both as percent. */
    function Sparkline(props) {
      const width = 100
      const height = 26
      const series = props.series.filter((entry) => entry.points.length > 0)
      const longest = series.reduce((max, entry) => Math.max(max, entry.points.length), 0)
      if (longest < 2) return null
      return h(
        'svg',
        {
          className: 'csq-spark',
          viewBox: `0 0 ${width} ${height}`,
          preserveAspectRatio: 'none',
          'aria-hidden': 'true',
        },
        series.map((entry, index) =>
          h('polyline', {
            key: index,
            fill: 'none',
            stroke: entry.color,
            strokeWidth: 1.5,
            vectorEffect: 'non-scaling-stroke',
            points: entry.points
              .map((value, position) => {
                const x = (position / Math.max(1, longest - 1)) * width
                const y = height - 1 - (Math.max(0, Math.min(100, value)) / 100) * (height - 2)
                return `${x.toFixed(1)},${y.toFixed(1)}`
              })
              .join(' '),
          }),
        ),
      )
    }

    /**
     * The codespace this page runs in, plus the one destructive action: stopping
     * it. Kept separate from the quota body because it works without any user
     * token — the platform's own codespace credential is enough.
     */
    function CodespaceSection(props) {
      const t = props.t
      const snapshot = useStore(csStore)
      const [confirming, setConfirming] = React.useState(false)
      const [busy, setBusy] = React.useState(false)
      const [outcome, setOutcome] = React.useState(null)
      const value = snapshot.value
      const canStop = value !== null && value.running === true && value.pendingOperation !== true

      const submit = () => {
        if (busy) return
        setBusy(true)
        setOutcome(null)
        stopCodespace()
          .then((payload) => {
            if (payload.ok !== true) {
              setOutcome({ kind: 'error', text: payload.error?.message ?? t('csFailed') })
              return
            }
            setConfirming(false)
            setOutcome({ kind: 'ok', text: t('csStopped') })
            csStore.set({ value: { ...value, state: 'ShuttingDown', stateLabel: t('csStopping'), running: false } })
          })
          .catch((error) => setOutcome({ kind: 'error', text: error?.message ?? String(error) }))
          .finally(() => setBusy(false))
      }

      const lines = []
      if (value !== null) {
        lines.push(['csq-mono', value.name])
        if (value.machine !== '') lines.push([null, value.machine])
        if (value.idleTimeoutMinutes !== null) lines.push([null, t('csIdle', { minutes: value.idleTimeoutMinutes })])
        if (value.repository !== '') lines.push([null, t('csRepo', { repo: value.repository })])
        if (value.lastUsedAt !== '') {
          lines.push([null, t('csLastUsed', { time: new Date(value.lastUsedAt).toLocaleString() })])
        }
      }

      return h(
        'div',
        { className: 'csq-section' },
        h(
          'div',
          { className: 'csq-sub', style: { marginBottom: 6 } },
          h('span', null, t('csTitle')),
          value === null ? null : h('span', { className: 'csq-badge' }, value.stateLabel ?? ''),
          h('span', { className: 'csq-spacer' }),
          value !== null && value.webUrl !== ''
            ? h(
                'a',
                { className: 'csq-link', href: value.webUrl, target: '_blank', rel: 'noreferrer noopener' },
                t('csOpen'),
              )
            : null,
        ),

        value === null
          ? snapshot.status === 'error'
            ? h(
                'div',
                null,
                h('div', { className: 'csq-error' }, snapshot.error?.message ?? t('csUnavailable')),
                snapshot.error?.detail === undefined ? null : h('div', { className: 'csq-line' }, snapshot.error.detail),
                h(
                  'div',
                  { className: 'csq-row' },
                  h('button', { type: 'button', className: 'csq-btn', onClick: () => loadCodespace() }, t('csRetry')),
                ),
              )
            : h('div', { className: 'csq-line' }, t('csLoading'))
          : h(
              'div',
              null,
              lines.map(([className, text], index) =>
                h('div', { className: className === null ? 'csq-line' : `csq-line ${className}`, key: index }, text),
              ),
            ),

        outcome === null
          ? null
          : h('div', { className: outcome.kind === 'ok' ? 'csq-ok' : 'csq-error', style: { marginTop: 6 } }, outcome.text),

        value !== null && value.pendingOperation === true
          ? h('div', { className: 'csq-line', style: { marginTop: 6 } }, t('csPending'))
          : null,

        canStop
          ? confirming
            ? h(
                'div',
                { className: 'csq-confirm' },
                h('div', { className: 'csq-line' }, h('b', null, t('csConfirm', { name: value.name }))),
                h('div', { className: 'csq-line' }, t('csStopWhy')),
                h(
                  'div',
                  { className: 'csq-row' },
                  h(
                    'button',
                    { type: 'button', className: 'csq-btn csq-btn-danger', disabled: busy, onClick: submit },
                    busy ? t('csStopping') : t('csConfirmYes'),
                  ),
                  h(
                    'button',
                    {
                      type: 'button',
                      className: 'csq-btn',
                      disabled: busy,
                      onClick: () => setConfirming(false),
                    },
                    t('csCancel'),
                  ),
                ),
              )
            : h(
                'div',
                { className: 'csq-row' },
                h(
                  'button',
                  { type: 'button', className: 'csq-btn csq-btn-danger', onClick: () => setConfirming(true) },
                  t('csStop'),
                ),
              )
          : null,
      )
    }

    function Body(props) {
      const t = props.t
      const snapshot = props.snapshot
      const value = snapshot.value

      if (value === null) {
        if (snapshot.status === 'error' && snapshot.error?.code !== 'no-token') {
          const error = snapshot.error ?? {}
          return h(
            'div',
            null,
            h('div', { className: 'csq-error' }, error.message ?? t('errorFallback')),
            error.detail === undefined ? null : h('div', { className: 'csq-note' }, error.detail),
            h(
              'div',
              { className: 'csq-row' },
              h('button', { type: 'button', className: 'csq-btn', onClick: () => load({ force: true }) }, t('retry')),
            ),
            h('div', { style: { marginTop: 10 } }, h(TokenForm, { t })),
          )
        }
        if (snapshot.status === 'loading') return h('div', { className: 'csq-note', style: { marginTop: 0 } }, t('loading'))
        return h(TokenForm, { t })
      }

      const percent = value.compute?.percent ?? null
      return h(
        'div',
        null,
        h(
          'div',
          { className: 'csq-sub' },
          h('span', null, `@${value.login}`),
          h('span', { className: 'csq-badge' }, value.planLabel ?? value.plan ?? ''),
          value.quotaAssumed === true ? h('span', { className: 'csq-badge' }, t('planAssumed')) : null,
        ),
        h(Metric, {
          t,
          label: t('compute'),
          used: value.compute?.used ?? 0,
          included: value.compute?.included ?? 0,
          remaining: value.compute?.remaining ?? null,
          percent,
          unit: value.compute?.unit ?? '',
        }),
        h(Metric, {
          t,
          label: t('storage'),
          used: value.storage?.used ?? 0,
          included: value.storage?.included ?? 0,
          remaining: value.storage?.remaining ?? null,
          percent: value.storage?.percent ?? null,
          unit: value.storage?.unit ?? '',
        }),
        h(
          'div',
          { className: 'csq-note' },
          h('div', null, t('resets', { label: value.period?.label ?? '', date: value.period?.resetsAt ?? '', days: value.period?.daysLeft ?? 0 })),
          h('div', null, t('updated', { time: new Date(snapshot.at || Date.now()).toLocaleTimeString() })),
          h('div', null, t('source', { source: value.source ?? '' })),
          value.tokenHint ? h('div', null, t('savedHint', { hint: value.tokenHint, source: value.tokenSource ?? '' })) : null,
          value.legacyPlaintext === true ? h('div', { className: 'csq-error' }, t('legacyWarn')) : null,
        ),
        h(Detail, { t, value }),
        snapshot.status === 'error'
          ? h('div', { className: 'csq-error', style: { marginTop: 8 } }, snapshot.error?.message ?? t('errorFallback'))
          : null,
      )
    }

    function PanelView(props) {
      const t = props.t
      const ui = useStore(uiStore)
      const snapshot = useStore(dataStore)

      React.useEffect(() => {
        if (!ui.open) return undefined
        loadCodespace()
        load()
        loadResources()
        return undefined
      }, [ui.open])

      React.useEffect(() => {
        if (!ui.open) return undefined
        const timer = setInterval(() => loadResources(), RESOURCES_REFRESH_MS)
        return () => clearInterval(timer)
      }, [ui.open])

      React.useEffect(() => {
        if (!ui.open) return undefined
        const timer = setInterval(() => {
          load({ force: true })
          loadCodespace()
        }, AUTO_REFRESH_MS)
        return () => clearInterval(timer)
      }, [ui.open])

      React.useEffect(() => {
        if (!ui.open) return undefined
        const onKey = (event) => {
          if (event.key === 'Escape') uiStore.set({ open: false })
        }
        window.addEventListener('keydown', onKey)
        return () => window.removeEventListener('keydown', onKey)
      }, [ui.open])

      if (!ui.open) return null

      return h(
        React.Fragment,
        null,
        h('div', { className: 'csq-backdrop', 'aria-hidden': 'true', onClick: () => uiStore.set({ open: false }) }),
        h(
          'section',
          { className: 'csq-panel', role: 'dialog', 'aria-label': t('title') },
          h(
            'div',
            { className: 'csq-head' },
            h('h2', null, t('title')),
            h(
              'button',
              {
                type: 'button',
                className: 'csq-iconbtn',
                title: t('refresh'),
                'aria-label': t('refresh'),
                disabled: snapshot.status === 'loading' || snapshot.status === 'refreshing',
                onClick: () => load({ force: true }),
              },
              h(
                'svg',
                { viewBox: '0 0 16 16', width: 15, height: 15, 'aria-hidden': 'true' },
                h('path', {
                  d: 'M13.2 6.4A5.6 5.6 0 1 0 13.4 9.6',
                  fill: 'none', stroke: 'currentColor', strokeWidth: 1.5, strokeLinecap: 'round',
                }),
                h('path', { d: 'M13.6 3.2v3.4h-3.4', fill: 'none', stroke: 'currentColor', strokeWidth: 1.5, strokeLinecap: 'round', strokeLinejoin: 'round' }),
              ),
            ),
            h(
              'button',
              {
                type: 'button',
                className: 'csq-iconbtn',
                title: t('close'),
                'aria-label': t('close'),
                onClick: () => uiStore.set({ open: false }),
              },
              h(
                'svg',
                { viewBox: '0 0 16 16', width: 15, height: 15, 'aria-hidden': 'true' },
                h('path', { d: 'M4 4l8 8M12 4l-8 8', stroke: 'currentColor', strokeWidth: 1.5, strokeLinecap: 'round' }),
              ),
            ),
          ),
          h(
            'div',
            { className: 'csq-body' },
            h(Body, { t, snapshot }),
            h(ResourcesSection, { t }),
            h(CodespaceSection, { t }),
          ),
        ),
      )
    }

    function Trigger(props) {
      const t = props.t
      const ui = useStore(uiStore)
      const snapshot = useStore(dataStore)
      const percent = snapshot.value?.compute?.percent ?? null
      const remaining = snapshot.value?.compute?.remaining ?? null
      const dotState =
        snapshot.status === 'error' && snapshot.value === null ? 'error' : snapshot.value === null ? 'idle' : levelOf(percent)
      return h(
        'button',
        {
          type: 'button',
          className: 'csq-trigger',
          title: t('trigger'),
          'aria-label': t('trigger'),
          'aria-expanded': ui.open ? 'true' : 'false',
          onClick: () => {
            uiStore.set({ open: !ui.open })
          },
        },
        h(Icon, { fill: percent === null ? 5.4 : 1.5 + (fillWidth(percent) / 100) * 9 }),
        // The wide column has room for the number (the shipped footer chips use up to 180px); the 56px rail does not.
        props.wide === true && typeof remaining === 'number'
          ? h('span', { className: 'csq-num' }, `${Math.round(remaining)}h`)
          : null,
        h('span', { className: 'csq-dot', 'data-state': dotState, 'aria-hidden': 'true' }),
      )
    }

    /* ---------------------------------------------------------------- plugin */

    return {
      inject: ['slots', 'locale'],
      apply(ctx) {
        ctx.effect(() => ctx.locale.register(NS, { zh, en }), 'dsh-codespace-quota: dictionaries')
        ctx.effect(() => installStyle(), 'dsh-codespace-quota: styles')

        const withTranslate = (Component) =>
          function Bound() {
            const t = useTranslate(ctx)
            return h(Component, { t })
          }

        ctx.slots.inject('sidebar.footer.action', () =>
          ctx.slots.register({ name: 'sidebar.footer.action', id: NS, order: 4 }, withTranslate(Trigger)),
        )
        ctx.slots.inject('shell.overlay', () =>
          ctx.slots.register({ name: 'shell.overlay', id: `${NS}-panel`, order: 20 }, withTranslate(PanelView)),
        )
      },
    }
  },
})
