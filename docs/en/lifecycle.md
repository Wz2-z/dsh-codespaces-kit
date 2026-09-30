# Lifecycle: status / doctor / setup / repair / update / uninstall

[← English docs](index.md) · [中文](../lifecycle.md)

```
dsh-codespaces status      one screen: what's happening right now
dsh-codespaces doctor      12 checks, host + cloud
dsh-codespaces audit       credential / permission inventory
dsh-codespaces setup       first-time install (idempotent)
dsh-codespaces repair      setup + doctor
dsh-codespaces update      upgrade dsh in the cloud, reopen the tunnel
dsh-codespaces uninstall   preview removal; nothing happens without -Yes/--yes
```

On Windows use `install\dsh-codespaces.bat <command>`; on macOS/Linux `install/dsh-codespaces.sh <command>`.
Arguments are passed straight through to the matching `*.ps1` / `*.sh`.

On Windows there is also a graphical **control panel** (`console.ps1` + `console.bat`) that turns
these commands into a menu: `[1]` open dsh · `[2]` status · `[3]` checkup · `[4]` auto sync · `[5]` update dsh ·
`[A]` credentials · `[R]` repair · `[U]` uninstall · `[L]` sync log, with `[E]` switching 中文 / English.
`setup.ps1` installs it — together with the scripts it calls — into `%LOCALAPPDATA%\dsh-cloud\` and creates the
"dsh 管理台" desktop shortcut; double-clicking `install\console.bat` inside a clone is the same panel.

## Which one, when

| Situation | Command |
| --- | --- |
| Just installed, want to confirm | `doctor` |
| Daily glance: is sync alive, when was the last push | `status` |
| "What permissions did this thing take?" | `audit` |
| New computer / new container | `setup` |
| Suddenly can't connect, sync stopped | `repair`, then `doctor` if it's still off |
| A new dsh release | `update` |
| Done with it | `uninstall` |

## What `status` looks like

```
╭──────────────────────────────────────────────────────────────────╮
│ dsh-codespaces status                                     v1.7.2 │
│ codespace                     your-codespace-name-here-gxq9gv9gx │
╰──────────────────────────────────────────────────────────────────╯

│ Codespace   Running   your-codespace（Available）
│ Tunnel      Healthy   127.0.0.1:3080 → 401 (token required = good)
│ DSH         Healthy   0.1.7-rc.2 · pid 62857 · HTTP 401
│ Auto sync   Running   idle · on · daemon pid 90277 · idle 600s · fold 1800s
│ Last check            32 seconds ago
│ Last push             1 minute ago · dsh: add projects/x (6 files)
│ Last commit           19a6c79 · 12 minutes ago · dsh: add projects/x (6 files)
│ Pending files           0
│ In sync               yes (local 19a6c79 / remote 19a6c79)
```

Status words: `Healthy` tunnel up and dsh wants a token (401 is normal) · `Down` unreachable ·
`Degraded` reachable but odd · `Running` / `Paused` / `Stopped` for the sync daemon.

`--quick` (bash) / `-Quick` (PowerShell) skips the tunnel probe; `--json` / `-Json` is for scripts;
`-Lang zh|en` (Windows, default `zh`) switches the output language of `status` / `doctor` / `audit`.

## What `repair` does

It re-runs the (idempotent) installer and then the checkup:

1. Host: install the portable gh if missing, recreate missing desktop shortcuts.
2. Cloud: install dsh if missing, clone the workspace, generate the deploy key, rewrite missing/broken
   `.dsh-cloud` scripts, start the sync daemon. **Your edited `sync.conf` is never overwritten.**
3. Then it runs `doctor` so you can see which line is still unhappy.

## `uninstall` scopes

Preview by default. To act, pass `-Yes`/`--yes` plus scopes:

| Flag | Effect |
| --- | --- |
| `-Local` / `--local` | delete desktop shortcuts (plus portable gh + SSH key when `-PurgeLocal`) |
| `-Cloud` / `--cloud` | stop the sync daemon and dsh web (`-PurgeCloud` also deletes `.dsh-cloud`) |
| `-RevokeDeployKey` | delete the deploy key from the repo (the platform token often lacks permission; it will tell you) |
| `-DeleteCodespace` | delete the whole Codespace (**irreversible**) |

It never touches your GitHub login, the repo contents, or the DeepSeek API key.
