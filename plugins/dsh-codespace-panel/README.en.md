# dsh-codespace-panel

Author: [@Wz2-z](https://github.com/Wz2-z) · License: MIT · [中文](README.md)

See your **GitHub Codespaces quota**, the **state and hardware usage (memory / CPU / disk) of the current
Codespace**, and **start / stop / restart** it — all from the DSH web UI. One bundle, one Host plugin,
seven EXACT routes.

- **Trigger button**: the battery icon at the foot of the sidebar, next to Settings
  (`sidebar.footer.action`, id `codespace-quota`). Once data has loaded it shows the remaining core-hours,
  and a small dot changes colour with usage.
- **Pop-up panel**: registered in the frame-level `shell.overlay`, so no column can clip it.
- **Codespace card** (top half): status dot + status text → machine/storage SKU → three live bars for
  memory / CPU / disk (colour-coded by usage) with a two-line trend for roughly the last 4 minutes →
  a 2×2 grid of `Start / Stop / Restart / Rebuild` → a footer line with "refresh time · processes · uptime"
  and the Git state (clean / uncommitted / unpushed + branch).
- **Quota card** (bottom half): plan, this month's compute quota (core-hours), storage quota (GB-month),
  progress bar, what's left, reset date, and the raw usage breakdown.

## Language

The panel follows **dsh's own language** (`ctx.locale.register`): both the Chinese and the English UI live in
`client.js` (the `zh` and `en` tables), and the title/description shown in the plugin list come from
`locale/zh.json` and `locale/en.json`. There is no separate switch.

The Host half returns error *codes* (`err_forbidden`, `err_auth`, `err_not_found`, …) and every visible word is
picked on the client — so error messages switch language along with everything else.

## What the control buttons can really do

Stopping the container takes DSH and this page with it, so "what can be done from inside the container" has
hard limits:

| Button | What actually happens |
| --- | --- |
| Start | Really calls `POST /user/codespaces/{name}/start`; only enabled while the state is `Shutdown` (normally the panel is only reachable while running, so it stays grey) |
| Stop | Really calls `.../stop`, with a confirmation. Quota and this page both end when it stops |
| Restart | `.../stop` first, then the Host fires one more `.../start` after 20 seconds. Stopping kills the process too, so that start **may not land**; if it doesn't, hit Start on github.com/codespaces |
| Rebuild | **There is no REST endpoint** (`gh codespace rebuild` uses the container's own gRPC channel), so this cell is a link: it opens the editor, where you run "Codespaces: Rebuild Container" from the command palette |

## Two credentials, two permission levels

| Feature | API | What it needs |
| --- | --- | --- |
| Quota numbers | [Billing API](https://docs.github.com/en/rest/billing/usage) | **A classic PAT with the `user` scope** (fine-grained tokens don't work for personal billing). Paste it into the panel; it is stored in DSH's credential store as `codespace-panel/quota-token` (`$DSH_HOME/.credentials.yaml`, mode 0600, never committed) |
| State / stop | [Codespaces API](https://docs.github.com/en/rest/codespaces/codespaces) | **The container's own platform token** (the one git/gh use, under `/workspaces/.codespaces/shared/`) — **zero setup** |

Tokens stay in the Host process; the browser never sees them. The quota token is looked up in this order:
the row's `token` config → environment (`GITHUB_TOKEN` / `GH_TOKEN` / `CODESPACE_QUOTA_TOKEN`) → the credential
store → the legacy plaintext file (read-only, for migration; saving a new token deletes it). This plugin no
longer writes any plaintext token file.

## Routes (all require the custom header `x-codespace-quota: 1`)

- `GET  /codespace-quota/summary[?refresh=1]` — quota snapshot
- `POST /codespace-quota/token` — save / clear the quota token
- `GET  /codespace-quota/codespace` — current Codespace state (machine SKU and git state included)
- `POST /codespace-quota/stop` — stop the current Codespace
- `POST /codespace-quota/start` — start the current Codespace
- `POST /codespace-quota/restart` — stop, then one start attempt 20 seconds later
- `GET  /codespace-quota/resources` — hardware snapshot (cgroup + statfs, no GitHub API involved)

All of them are EXACT routes: the web server consults the exact table before the prefix table, so nobody gets
shadowed by someone else's prefix route.

Every successful response carries `data.version`, which is this package's `version` from `package.json`
(the Host reads the `package.json` in its own directory); the panel header shows it as `v0.2.0`.

## Versioning

The **only** source of the version is `version` in `package.json` — nothing else in the repo hard-codes it:

- the panel header shows `v<version>` (the Host sends it with every successful response; the client never
  hard-codes it);
- the DSH plugin page shows that same package version;
- to release, change `package.json` and restart dsh (Host code is cached inside the running process).

Current: **v0.2.0**.

## Optional config

Put it on this plugin's row in your own profile `cordis.patch.yml` (the Host half validates it; unknown keys are
logged and ignored):

```yaml
- id: codespace-panel
  name: 'dsh-codespace-panel'
  config:
    includedCoreHours: 180   # 0 = infer from the plan (Free 120 / Pro 180)
    includedStorageGb: 20    # 0 = infer from the plan (Free 15 / Pro 20)
    cacheSeconds: 120
```

## Design constraints (things that bit us)

1. **Insert exactly one row, and make it activate on the first try**: a loader row that ends up `inactive`
   breaks the "configurable entries" view that other plugins' settings forms bind to — and `dsh-remote-web-ui`
   binds its form once per page session, so once that breaks it never registers its sidebar button again until
   a refresh or restart. The first install coexisted with it precisely because no row failed that time.
2. **No exported `Config` schema**: the config is normalised by hand inside `apply`, so this plugin adds no
   unusual shape to the profile's configurable-entries surface.
3. **The client puts one constant-size icon in `sidebar.footer.action`**: that row's layout is taken over by
   `dsh-remote-web-ui` and `dsh-cost-meter`, so resizing or appearing/disappearing pushes other controls around.

## Screenshot

![Codespaces quota panel](./screenshots/panel.png)

> The panel that opens from the battery icon at the foot of the sidebar: this month's quota (core-hours /
> storage), hardware usage, the current Codespace state and one-click stop. The Codespace and repo names in the
> screenshot are redacted.
