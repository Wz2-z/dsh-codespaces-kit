/**
 * dsh-sync-panel — Client half.
 *
 * 两个 slot 项共用一个模块级的 store：
 *   - `sidebar.footer.action`  侧边栏底部的小按钮（和额度按钮并排）
 *   - `shell.overlay`          点开后的面板（必须放在 frame 级浮层，才不会被栏裁剪）
 *
 * 所有数据都来自 Host 半边的 /sync-panel/*，这一半不碰 git、不碰凭据。
 * 按钮保持恒定尺寸：footer 是和别的插件共用的座位，忽大忽小会带动别人的控件。
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
    const dataStore = createStore({ status: 'idle', value: null, error: null, busy: '', toast: '', at: 0 })

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
        throw new Error(`返回的不是 JSON（HTTP ${response.status}）`)
      }
      if (json?.ok !== true) throw new Error(json?.error?.message ?? `HTTP ${response.status}`)
      return json.data
    }

    async function refresh() {
      dataStore.set({ status: 'loading' })
      try {
        const data = await call('/summary')
        dataStore.set({ status: 'ready', value: data, error: null, at: Date.now() })
      } catch (error) {
        dataStore.set({ status: 'error', error: String(error?.message ?? error) })
      }
    }

    async function act(payload) {
      dataStore.set({ busy: payload.action, toast: '' })
      try {
        const data = await call('/action', { method: 'POST', body: JSON.stringify(payload) })
        dataStore.set({
          busy: '',
          status: 'ready',
          value: data.summary ?? dataStore.get().value,
          toast: (data.output || '完成').split('\n').slice(-2).join(' / '),
        })
      } catch (error) {
        dataStore.set({ busy: '', error: String(error?.message ?? error), toast: '' })
      }
      setTimeout(() => dataStore.set({ toast: '' }), 4000)
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

    function Trigger() {
      const ui = useStore(uiStore)
      const snapshot = useStore(dataStore)
      const value = snapshot.value
      const on = value ? value.conf?.enabled !== 'off' : null
      return h(
        'button',
        {
          type: 'button',
          className: 'dsp-trigger',
          title: '自动同步',
          'aria-label': '自动同步',
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

    function PanelView() {
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
        ['now', '立即提交', true],
        ['pause', '暂停', false],
        ['resume', '恢复', false],
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
        [1800, '折进 30 分钟'],
        [0, '关闭折叠'],
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
            h('span', { className: 'dsp-title' }, '自动同步'),
            h(
              'button',
              { type: 'button', className: 'dsp-btn', onClick: () => refresh(), disabled },
              '刷新',
            ),
          ),
          snapshot.error ? h('div', { className: 'dsp-err' }, String(snapshot.error)) : null,
          h(
            'div',
            { className: 'dsp-badges' },
            Badge(`模式 ${conf.mode ?? '—'}`, true),
            Badge(conf.enabled === 'off' ? '已暂停' : '同步中', conf.enabled !== 'off'),
            Badge(value?.daemon ? '守护进程在跑' : '守护进程没在跑', Boolean(value?.daemon)),
          ),
          Row('待提交', value ? `${value.pendingCount} 个文件` : '…'),
          pendingList.length
            ? h('div', { className: 'dsp-mono' }, pendingList.join('\n'))
            : null,
          Row('最近提交', h('span', { className: 'dsp-mono' }, value?.lastCommit ?? '…')),
          Row('折叠窗口', conf.squash_window_seconds ? `${conf.squash_window_seconds} 秒` : '关闭'),
          Row('静默阈值', conf.idle_seconds ? `${conf.idle_seconds} 秒` : '—'),
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
          snapshot.toast ? h('div', { className: 'dsp-toast' }, snapshot.toast) : null,
        ),
      )
    }

    /* ---------------------------------------------------------------- plugin */

    return {
      inject: ['slots'],
      apply(ctx) {
        ctx.effect(() => installStyle(), 'dsh-sync-panel: styles')
        ctx.slots.inject('sidebar.footer.action', () =>
          ctx.slots.register({ name: 'sidebar.footer.action', id: NS, order: 5 }, Trigger),
        )
        ctx.slots.inject('shell.overlay', () =>
          ctx.slots.register({ name: 'shell.overlay', id: `${NS}-panel`, order: 21 }, PanelView),
        )
      },
    }
  },
})
