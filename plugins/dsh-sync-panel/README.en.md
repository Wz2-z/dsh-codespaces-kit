# dsh-sync-panel

Author: [@Wz2-z](https://github.com/Wz2-z) · License: MIT · [中文](README.md)

A **sync button** at the foot of the dsh sidebar: open it to see the state of auto sync and to drive it —
no more SSH-ing into the container to run `sync.sh --status`.

## What's in the panel

- **Badges**: current mode (`idle` / `interval` / `manual`), running or paused, daemon up or not
- **Pending**: how many files, and which ones (up to 6)
- **Last commit**: e.g. `af51acc dsh: update projects/x (12 files)`
- **Fold window / idle threshold**: the seconds currently in effect
- **Recent log**: the tail of `~/dsh-sync.log` (`pushed` / `folded` / `skipped` / `FAILED`)
- **Buttons**: commit now, pause, resume, switch mode (idle / interval / manual), fold window on/off

## Language

The panel follows **dsh's own language** (`ctx.locale`): a Chinese dsh gets the Chinese panel, an English dsh
gets the English one — there is no separate switch. Both dictionaries live in `client.js` (the `zh` and `en`
tables, same keys in both), and the title/description shown in the plugin list come from `locale/zh.json`
and `locale/en.json`.

The Host half only returns error *codes* (`no-sync-script`, `bad-mode`, `bad-action`, …) and the client picks
the wording. The one exception is `command-failed`: it carries `sync.sh`'s own output and is shown as-is
(those strings live in the cloud script).

## Install

Run this **inside your own dsh Codespace container**:

```bash
# 1) fetch the plugin
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public

# 2) install it into the dsh web profile
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-sync-panel

# 3) make it load at startup: add "dsh-sync-panel" to dsh.profile.bundles in package.json
#    "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-sync-panel"]
```

Restart dsh (the `dsh web` process) and refresh the page — the sync icon appears at the foot of the sidebar.

## The two halves

| Half | What it does |
| --- | --- |
| Host (`index.js`) | Two EXACT routes: `GET /sync-panel/summary` reads the state; `POST /sync-panel/action` runs `sync.sh --disable/--enable/--now/--mode=/--squash-window=` on your behalf |
| Client (`client.js`) | One constant-size footer button plus a `shell.overlay` panel; it only talks to those two routes |

Both routes require the custom header `x-sync-panel: 1`, which other pages in the browser cannot set.
The Host half never touches git credentials or the API key — it only runs the `sync.sh` that already lives
in your repo.

## Optional config

Put it on this plugin's row in the profile `cordis.patch.yml` (unknown keys are logged and ignored):

```yaml
- id: sync-panel
  name: 'dsh-sync-panel'
  config:
    dir: /workspaces/<repo>/.dsh-cloud   # omitted: look it up under /workspaces/*/.dsh-cloud
    workspace: /home/codespace/dsh-workspace
    timeoutMs: 60000
    logLines: 8
```

## Design constraints (things that bit us)

1. **Insert exactly one row, and make it activate on the first try**: a loader row that ends up `inactive`
   breaks the "configurable entries" view that other plugins' settings forms bind to. The first install
   coexisted with `dsh-codespace-panel` precisely because no row failed that time.
2. **The footer button keeps a constant size**: that row's layout is taken over by `dsh-remote-web-ui`,
   `dsh-cost-meter` and `dsh-codespace-panel`, so growing or disappearing pushes other people's controls around.
3. **The panel must live in `shell.overlay`**: inside `sidebar.footer.action` it gets clipped by the column.
4. No exported `Config` schema — the config is normalised by hand inside `apply`.
