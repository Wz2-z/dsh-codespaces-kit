/**
 * dsh-sync-panel — Client half.
 *
 * 两个 slot 项共用一个模块级的 store：
 *   - `sidebar.footer.action`  侧边栏底部的小按钮（和额度按钮并排）
 *   - `shell.overlay`          点开后的面板（必须放在 frame 级浮层，才不会被栏裁剪）
 *
 * 所有数据都来自 Host 半边的 /sync-panel/*，这一半不碰 git、不碰凭据。
 * 按钮保持恒定尺寸：footer 是和别的插件共用的座位，忽大忽小会带动别人的控件。
 *
 * 文案走 dsh 的 locale 服务（和 dsh-codespace-panel 同一套）：界面语言跟着 dsh 走，
 * 中文 / English 都有；Host 半边只回错误码（比如 no-sync-script），具体措辞在这里挑。
 */
window.__ModuleLoader__.load({
  id: 'dsh-sync-panel',
  factory(require) {
    const React = require('react')
    const h = React.createElement

    const NS = 'sync-panel'
    const ROUTE = '/sync-panel'
    const FENCE = { 'x-sync-panel': '1' }
    const AUTO_REFRESH_MS = 60 * 1000

    /* ---------------------------------------------------------------- 文案 */

    const zh = {
      trigger: '自动同步',
      title: '自动同步',
      refresh: '刷新',
      done: '完成',
      modeBadge: '模式 {mode}',
      paused: '已暂停',
      running: '同步中',
      daemonOn: '守护进程在跑',
      daemonOff: '守护进程没在跑',
      pending: '待提交',
      pendingFiles: '{count} 个文件',
      lastCommit: '最近提交',
      foldWindow: '折叠窗口',
      seconds: '{seconds} 秒',
      off: '关闭',
      idleThreshold: '静默阈值',
      none: '—',
      commitNow: '立即提交',
      pause: '暂停',
      resume: '恢复',
      fold30: '折进 30 分钟',
      foldOff: '关闭折叠',
      err_forbidden: '请求被拒绝（缺少插件请求头，或来自跨站页面）',
      err_method: '请求方法不对',
      err_no_sync_script: '没找到 .dsh-cloud/sync.sh（可以用配置项 dir 指定它的目录）',
      err_bad_mode: '模式只能是 idle / interval / manual',
      err_bad_action: '未知操作',
      err_too_large: '请求体过大',
      err_bad_json: '请求体不是合法 JSON',
      err_http: 'Host 返回了错误状态',
      err_no_json: 'Host 返回的不是 JSON（HTTP {status}）',
      err_unknown: '未知错误',
    }

    const en = {
      trigger: 'Auto sync',
      title: 'Auto sync',
      refresh: 'Refresh',
      done: 'done',
      modeBadge: 'mode {mode}',
      paused: 'paused',
      running: 'running',
      daemonOn: 'daemon running',
      daemonOff: 'daemon not running',
      pending: 'Pending',
      pendingFiles: '{count} files',
      lastCommit: 'Last commit',
      foldWindow: 'Fold window',
      seconds: '{seconds}s',
      off: 'off',
      idleThreshold: 'Idle threshold',
      none: '—',
      commitNow: 'Commit now',
      pause: 'Pause',
      resume: 'Resume',
      fold30: 'Fold 30 min',
      foldOff: 'Fold off',
      err_forbidden: 'request refused (missing plugin header, or a cross-site caller)',
      err_method: 'wrong HTTP method',
      err_no_sync_script: 'could not find .dsh-cloud/sync.sh (set the dir option if it lives elsewhere)',
      err_bad_mode: 'mode must be idle / interval / manual',
      err_bad_action: 'unknown action',
      err_too_large: 'request body is too large',
      err_bad_json: 'request body is not valid JSON',
      err_http: 'the Host answered with an error status',
      err_no_json: 'the Host did not answer with JSON (HTTP {status})',
      err_unknown: 'unknown error',
    }

    /* ------------------------------------------------------------ 极简 store */

    function createStore(initial) {
      let state = initial
      const listeners = new Set()
      return {
        get: () => state,
        set(patch) {
          state = typeof patch === 'function' ? patch(state) : { ...state, ...patch }
          for (const listener of listeners) listener()
        },
        subscribe(listener) {
          listeners.add(listener)
          return () => listeners.delete(listener)
        },
      }
    }

    function useStore(store) {
      const [, force] = React.useState(0)
      React.useEffect(() => store.subscribe(() => force((n) => n + 1)), [store])
      return store.get()
    }

    const uiStore = createStore({ open: false })
    const dataStore = createStore({ status: 'idle', value: null, error: null, busy: '', toast: '', toastKey: '', at: 0 })

    /* -------------------------------------------------------------- 翻译 */

    function useSubscribed(subscribe, read) {
      const [value, setValue] = React.useState(read)
      React.useEffect(() => subscribe(() => setValue(read())), [subscribe, read])
      return value
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

    // Host 回的是错误码（command-failed 那条带着 sync.sh 自己的输出，字典里故意不收，
    // 这样它会原样透出来，比一句笼统的"失败了"有用）
    function errorText(t, error, fallbackKey) {
      const code = typeof error?.code === 'string' ? error.code : ''
      const key = `err_${code.replace(/-/g, '_')}`
      if (code !== '' && t(key) !== key) return t(key, { status: error?.detail?.status ?? '?' })
      return error?.message ?? (fallbackKey === undefined ? '' : t(fallbackKey))
    }

    /* ------------------------------------------------------------------ 样式 */

    function installStyle() {
      if (document.getElementById('dsh-sync-panel-style')) return
      const style = document.createElement('style')
      style.id = 'dsh-sync-panel-style'
      style.textContent = `
        .dsp-trigger{display:inline-flex;align-items:center;justify-content:center;gap:4px;
          width:24px;height:24px;padding:0;border:0;border-radius:4px;background:transparent;
          color:var(--vscode-icon-foreground,#c5c5c5);cursor:pointer}
        .dsp-trigger:hover{background:var(--vscode-toolbar-hoverBackground,rgba(90,93,94,.31))}
        .dsp-trigger[data-on="false"]{color:var(--vscode-disabledForeground,#6b6b6b)}
        .dsp-trigger .dsp-dot{width:5px;height:5px;border-radius:50%;background:currentColor;opacity:.45}
        .dsp-trigger[data-busy="true"] .dsp-dot{animation:dsp-pulse 1s ease-in-out infinite}
        @keyframes dsp-pulse{0%,100%{opacity:.25}50%{opacity:.9}}
        .dsp-backdrop{position:fixed;inset:0;z-index:60;background:transparent}
        .dsp-card{position:absolute;left:10px;bottom:10px;width:380px;max-height:70vh;overflow:auto;
          padding:12px 12px 10px;border-radius:8px;font-size:12px;line-height:1.5;
          background:var(--vscode-editorWidget-background,#252526);
          color:var(--vscode-editorWidget-foreground,#ccc);
          border:1px solid var(--vscode-widget-border,rgba(255,255,255,.15));
          box-shadow:0 4px 16px rgba(0,0,0,.35)}
        .dsp-head{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:8px}
        .dsp-title{font-weight:600;font-size:12.5px}
        .dsp-badges{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px}
        .dsp-badge{padding:1px 6px;border-radius:9px;font-size:11px;
          border:1px solid var(--vscode-widget-border,rgba(255,255,255,.2))}
        .dsp-badge[data-on="true"]{color:#8fd18f;border-color:#3f6b3f}
        .dsp-badge[data-on="false"]{color:#d1a28f;border-color:#6b4a3f}
        .dsp-row{display:flex;gap:6px;margin:2px 0}
        .dsp-k{color:var(--vscode-descriptionForeground,#9d9d9d);min-width:66px}
        .dsp-v{flex:1;word-break:break-all}
        .dsp-mono{font-family:var(--vscode-editor-font-family,monospace);font-size:11px;white-space:pre-wrap}
        .dsp-actions{display:flex;flex-wrap:wrap;gap:6px;margin:10px 0 6px}
        .dsp-btn{padding:3px 9px;border-radius:4px;font-size:11.5px;cursor:pointer;
          border:1px solid var(--vscode-button-border,transparent);
          background:var(--vscode-button-secondaryBackground,#3a3d41);
          color:var(--vscode-button-secondaryForeground,#ccc)}
        .dsp-btn:hover{background:var(--vscode-button-secondaryHoverBackground,#45494e)}
        .dsp-btn[data-primary="true"]{background:var(--vscode-button-background,#0e639c);
          color:var(--vscode-button-foreground,#fff)}
        .dsp-btn:disabled{opacity:.5;cursor:default}
        .dsp-log{margin-top:8px;padding:6px;border-radius:4px;max-height:120px;overflow:auto;
          background:var(--vscode-textCodeBlock-background,rgba(255,255,255,.06))}
        .dsp-toast{margin-top:8px;color:var(--vscode-descriptionForeground,#9d9d9d)}
        .dsp-err{color:var(--vscode-errorForeground,#f48771)}
      `
      document.head.appendChild(style)
    }

    /* ------------------------------------------------------------- 数据访问 */

    async function call(path, init) {
      const hasBody = Boolean(init?.body)
      const response = await fetch(`${ROUTE}${path}`, {
        ...init,
        headers: { ...FENCE, ...(hasBody ? { 'content-type': 'application/json' } : {}) },
      })
      const text = await response.text()
      let json = null
      try {
        json = JSON.parse(text)
      } catch {
        throw Object.assign(new Error(`HTTP ${response.status}`), {
          code: 'no-json',
          detail: { status: response.status },
        })
      }
      if (json?.ok !== true) {
        throw Object.assign(new Error(json?.error?.message ?? `HTTP ${response.status}`), {
          code: typeof json?.error?.code === 'string' ? json.error.code : 'http',
          detail: { status: response.status },
        })
      }
      return json.data
    }

    async function refresh() {
      dataStore.set({ status: 'loading' })
      try {
        const data = await call('/summary')
        dataStore.set({ status: 'ready', value: data, error: null, at: Date.now() })
      } catch (error) {
        dataStore.set({ status: 'error', error })
      }
    }

    async function act(payload) {
      dataStore.set({ busy: payload.action, toast: '', toastKey: '' })
      try {
        const data = await call('/action', { method: 'POST', body: JSON.stringify(payload) })
        const output = (data.output || '').split('\n').slice(-2).join(' / ')
        dataStore.set({
          busy: '',
          status: 'ready',
          value: data.summary ?? dataStore.get().value,
          toast: output,
          toastKey: output ? '' : 'done',
          error: null,
        })
      } catch (error) {
        dataStore.set({ busy: '', error, toast: '', toastKey: '' })
      }
      setTimeout(() => dataStore.set({ toast: '', toastKey: '' }), 4000)
    }

    /* --------------------------------------------------------------- 组件 */

    function Icon() {
      return h(
        'svg',
        {
          width: 15,
          height: 15,
          viewBox: '0 0 16 16',
          fill: 'none',
          stroke: 'currentColor',
          strokeWidth: 1.4,
          strokeLinecap: 'round',
          strokeLinejoin: 'round',
          'aria-hidden': 'true',
        },
        h('path', { d: 'M2.5 6.5A4.5 4.5 0 0 1 11 4.2' }),
        h('path', { d: 'M11 2.2v2.4H8.6' }),
        h('path', { d: 'M13.5 9.5A4.5 4.5 0 0 1 5 11.8' }),
        h('path', { d: 'M5 13.8v-2.4h2.4' }),
      )
    }

    function Trigger(props) {
      const t = props.t
      const ui = useStore(uiStore)
      const snapshot = useStore(dataStore)
      const value = snapshot.value
      const on = value ? value.conf?.enabled !== 'off' : null
      return h(
        'button',
        {
          type: 'button',
          className: 'dsp-trigger',
          title: t('trigger'),
          'aria-label': t('trigger'),
          'aria-expanded': ui.open ? 'true' : 'false',
          'data-on': on === false ? 'false' : 'true',
          'data-busy': snapshot.status === 'loading' || snapshot.busy !== '' ? 'true' : 'false',
          onClick: () => {
            const next = !ui.open
            uiStore.set({ open: next })
            if (next) refresh()
          },
        },
        h(Icon, null),
        h('span', { className: 'dsp-dot', 'aria-hidden': 'true' }),
      )
    }

    function Badge(text, on) {
      return h('span', { className: 'dsp-badge', 'data-on': on ? 'true' : 'false' }, text)
    }

    function Row(key, value) {
      return h('div', { className: 'dsp-row' }, h('span', { className: 'dsp-k' }, key), h('span', { className: 'dsp-v' }, value))
    }

    function PanelView(props) {
      const t = props.t
      const ui = useStore(uiStore)
      const snapshot = useStore(dataStore)

      React.useEffect(() => {
        if (!ui.open) return undefined
        if (snapshot.status === 'idle') refresh()
        const timer = setInterval(() => {
          if (uiStore.get().open) refresh()
        }, AUTO_REFRESH_MS)
        const onKey = (event) => {
          if (event.key === 'Escape') uiStore.set({ open: false })
        }
        document.addEventListener('keydown', onKey)
        return () => {
          clearInterval(timer)
          document.removeEventListener('keydown', onKey)
        }
      }, [ui.open, snapshot.status])

      if (!ui.open) return null

      const value = snapshot.value
      const conf = value?.conf ?? {}
      const busy = snapshot.busy !== ''
      const disabled = busy || snapshot.status === 'loading'
      const pendingList = value?.pendingFiles ?? []

      const buttons = [
        ['now', t('commitNow'), true],
        ['pause', t('pause'), false],
        ['resume', t('resume'), false],
      ].map(([action, label, primary]) =>
        h(
          'button',
          {
            key: action,
            type: 'button',
            className: 'dsp-btn',
            'data-primary': primary ? 'true' : 'false',
            disabled,
            onClick: () => act({ action }),
          },
          label,
        ),
      )

      const modes = ['idle', 'interval', 'manual'].map((mode) =>
        h(
          'button',
          {
            key: mode,
            type: 'button',
            className: 'dsp-btn',
            'data-primary': conf.mode === mode ? 'true' : 'false',
            disabled,
            onClick: () => act({ action: 'mode', mode }),
          },
          mode,
        ),
      )

      const squash = [
        [1800, t('fold30')],
        [0, t('foldOff')],
      ].map(([seconds, label]) =>
        h(
          'button',
          {
            key: seconds,
            type: 'button',
            className: 'dsp-btn',
            disabled,
            onClick: () => act({ action: 'squash', squashWindow: seconds }),
          },
          label,
        ),
      )

      return h(
        'div',
        { className: 'dsp-backdrop', onClick: () => uiStore.set({ open: false }) },
        h(
          'div',
          { className: 'dsp-card', onClick: (event) => event.stopPropagation() },
          h(
            'div',
            { className: 'dsp-head' },
            h('span', { className: 'dsp-title' }, t('title')),
            h(
              'button',
              { type: 'button', className: 'dsp-btn', onClick: () => refresh(), disabled },
              t('refresh'),
            ),
          ),
          snapshot.error ? h('div', { className: 'dsp-err' }, errorText(t, snapshot.error, 'err_unknown')) : null,
          h(
            'div',
            { className: 'dsp-badges' },
            Badge(t('modeBadge', { mode: conf.mode ?? t('none') }), true),
            Badge(conf.enabled === 'off' ? t('paused') : t('running'), conf.enabled !== 'off'),
            Badge(value?.daemon ? t('daemonOn') : t('daemonOff'), Boolean(value?.daemon)),
          ),
          Row(t('pending'), value ? t('pendingFiles', { count: value.pendingCount }) : '…'),
          pendingList.length
            ? h('div', { className: 'dsp-mono' }, pendingList.join('\n'))
            : null,
          Row(t('lastCommit'), h('span', { className: 'dsp-mono' }, value?.lastCommit ?? '…')),
          Row(t('foldWindow'), conf.squash_window_seconds ? t('seconds', { seconds: conf.squash_window_seconds }) : t('off')),
          Row(t('idleThreshold'), conf.idle_seconds ? t('seconds', { seconds: conf.idle_seconds }) : t('none')),
          h('div', { className: 'dsp-actions' }, buttons),
          h('div', { className: 'dsp-actions' }, modes),
          h('div', { className: 'dsp-actions' }, squash),
          value?.log?.length
            ? h(
                'div',
                { className: 'dsp-log dsp-mono' },
                value.log.slice(-6).join('\n'),
              )
            : null,
          snapshot.toast || snapshot.toastKey
            ? h('div', { className: 'dsp-toast' }, snapshot.toast || t(snapshot.toastKey))
            : null,
        ),
      )
    }

    /* ---------------------------------------------------------------- plugin */

    return {
      inject: ['slots', 'locale'],
      apply(ctx) {
        ctx.effect(() => ctx.locale.register(NS, { zh, en }), 'dsh-sync-panel: dictionaries')
        ctx.effect(() => installStyle(), 'dsh-sync-panel: styles')

        const withTranslate = (Component) =>
          function Bound() {
            const t = useTranslate(ctx)
            return h(Component, { t })
          }

        ctx.slots.inject('sidebar.footer.action', () =>
          ctx.slots.register({ name: 'sidebar.footer.action', id: NS, order: 5 }, withTranslate(Trigger)),
        )
        ctx.slots.inject('shell.overlay', () =>
          ctx.slots.register({ name: 'shell.overlay', id: `${NS}-panel`, order: 21 }, withTranslate(PanelView)),
        )
      },
    }
  },
})
