# Run DeepSeek Harness (dsh) on GitHub Codespaces

[中文](README.md) · **English**

Run the official dsh inside a Codespace, keep your work in your own private repo, and reach it from your own
machine through one SSH tunnel. Your computer only needs a portable GitHub CLI — no admin rights, no Node/Python,
no credit card.

| | |
| --- | --- |
| **Who it's for** | People who want the official dsh without running an agent locally, without a cloud VM, and with a fully isolated environment |
| **Cost** | Free **within the Codespaces quota included in your account** (free tier: 120 core-hours + 15 GB-month). **Going over the quota may cost money** |
| **What you install locally** | A portable GitHub CLI. No admin rights, no Node/Python, nothing added to `PATH` |
| **How long** | ~15–20 minutes the first time, most of it waiting |

> This guide contains no personal information. Placeholders such as `<your-username>`, `<repo-name>`,
> `<codespace-name>` are meant to be replaced. Version numbers look like `v22.x.y`.

---

## 30-second overview

```
your computer                          GitHub Codespaces (cloud container)
┌────────────────────┐                 ┌──────────────────────────────┐
│ browser            │                 │  dsh web                     │
│  127.0.0.1:3080 ◄──┼── SSH tunnel ───┼─► listens on 127.0.0.1:3080 │
│                    │                 │                              │
│ portable gh CLI    │                 │  ~/dsh-workspace (workspace) │
│  + SSH key         │                 │   = a clone of your repo     │
└────────────────────┘                 │  commits when idle (batching)│
                                       └──────────────────────────────┘
```

Four things to remember:

1. **dsh runs inside the container** and cannot touch your local files.
2. **You must use an SSH tunnel** — GitHub's `*.app.github.dev` URL does not work for dsh
   ([why](docs/en/troubleshooting.md#the-github-port-forwarding-url-does-not-work)).
3. **The workspace is a private GitHub repo**, so your work is versioned automatically.
4. **You only do five steps** (or run the one-shot installer in [`install/`](install/)).

Once it's up, one command tells you whether everything is healthy:
[`dsh-codespaces doctor`](#checkup-dsh-codespaces-doctor) — 12 checks, host + cloud.

---

## Quick install (~15–20 minutes)

### What you need

| Need | Notes |
| --- | --- |
| A GitHub account | 13+ to sign up; under 18 needs a parent's consent. Free tier is enough |
| A computer | Windows 10/11, macOS, or Linux |
| Network | Must be able to reach github.com |
| **Not needed** | Credit card, admin rights, local Node/Python |

### Route A — one-shot installer (recommended)

**Windows** (normal user rights):

```powershell
irm https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/setup.ps1 -OutFile setup.ps1
notepad setup.ps1        # look before you run
powershell -ExecutionPolicy Bypass -File setup.ps1 -Repo your-name/your-repo
```

**macOS / Linux**:

```bash
curl -fsSLO https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/setup.sh
less setup.sh            # look before you run
bash setup.sh --repo=your-name/your-repo
```

The installer walks this pipeline:

```
check GitHub CLI → check Codespace → check Node → install dsh →
configure workspace → generate deploy key → configure sync → verify
```

and ends with `✅ Installation complete`, plus launchers on your desktop.

### Route B — do it yourself, five steps

1. **Create a private repo** (<https://github.com/new>) — tick *Add a README file*.
2. **Create a Codespace** (<https://github.com/codespaces> → New codespace) for that repo; 2-core is enough.
   Raise the idle timeout at <https://github.com/settings/codespaces> (e.g. 240 minutes).
3. **Hand the task book to your AI**: copy [docs/en/ai-prompt.md](docs/en/ai-prompt.md), fill in the
   placeholders, and give it to any coding agent (Codex, dsh, …).
4. **Do the one-time authorization**: run `gh auth login`, open <https://github.com/login/device>, paste the
   code, authorize.
5. **From then on, just double-click**: the start launcher wakes the Codespace, starts dsh, opens the tunnel
   and your browser.

---

## Configuration

### In the dsh UI, first time

1. Settings → Models → DeepSeek card → paste your **DeepSeek API key** (use a low-limit, revocable key).
2. Pick a model: `deepseek-flash` (text + images) or `deepseek-v4-pro` (text only, stronger).
3. Pick the workspace: `~/dsh-workspace` (never your home directory — that's where credentials live).

### Permissions (conservative by default)

- New sessions use `workspace-write` + `ask`: it may edit the workspace, sensitive actions ask you first.
- Switch to `read-only` for stricter.
- `danger-full-access` requires approval (`ask`, not `never`).

Exact YAML: [docs/en/ai-runbook.md](docs/en/ai-runbook.md).

### Optional plugins

| Plugin | What it does |
| --- | --- |
| [`dsh-codespace-panel`](plugins/dsh-codespace-panel/) | Codespaces quota in the dsh sidebar + one-click stop |
| [`dsh-sync-panel`](plugins/dsh-sync-panel/) | Auto-sync status in the sidebar: mode, pending files, commit now, pause/resume |

Install steps: [docs/en/plugins.md](docs/en/plugins.md).

> Plugins run inside the dsh host process with your container's permissions — prefer well-known sources, and
> try unknown ones under `read-only` first.

---

## Daily use

| I want to… | Do this |
| --- | --- |
| Start | Double-click the **DeepSeek Harness** (or **dsh control panel**) desktop shortcut |
| See the current state | `dsh-codespaces status`, or menu item 2 in the control panel |
| Health check | `dsh-codespaces doctor` |
| Commit right now | `bash .dsh-cloud/sync.sh --now` in the container, or control panel → 4 → 2 |
| Save quota | <https://github.com/codespaces> → **Stop** |
| See usage | <https://github.com/settings/billing> → Codespaces |
| Move to a new computer | run `install/setup.ps1` (or `.sh`) there — see [docs/en/macos-linux.md](docs/en/macos-linux.md) |
| Something's broken | `dsh-codespaces repair`, then `dsh-codespaces doctor` |
| Logs | container: `~/dsh-web.log`, `~/dsh-sync.log`, `~/dsh-update.log`; host: next to the launcher |

**Data retention**: a Codespace is deleted after **30 days of inactivity** (`~/dsh-workspace` and `~/.dsh`
go with it), so the workspace must be pushed to your repo. Session history (`~/.dsh`) is *not* in the repo.

**Security reminders**:

- Never put keys or passwords in the workspace — everything there is pushed to the repo.
- `~/.dsh/.credentials.yaml` (API key) and `~/.ssh` stay out of the agent's way.
- See [docs/en/security-model.md](docs/en/security-model.md) for the full inventory.

### Auto sync

The workspace is committed and pushed **after the changes stop**, not every N minutes, and commit messages are
generated from what changed (`dsh: update projects/x (12 files)`). Three modes: `idle` (default), `interval`,
`manual`; plus an optional "fold into the previous commit" window.

Details: [docs/en/auto-sync.md](docs/en/auto-sync.md).

---

## Checkup: `dsh-codespaces doctor`

```
dsh-codespaces status      one screen: codespace / tunnel / dsh / sync / last push / pending
dsh-codespaces doctor      12 checks (host + cloud)
dsh-codespaces audit       what keys / tokens / configs exist, what each can do
dsh-codespaces setup       first-time install (idempotent)
dsh-codespaces repair      re-run setup, then doctor
dsh-codespaces update      upgrade dsh in the cloud and reopen the tunnel
dsh-codespaces uninstall   preview removal; add -Yes/--yes and scopes to actually do it
```

`doctor` output looks like this:

```
GitHub CLI               ✓  gh version 2.101.0
GitHub authentication    ✓  logged in: <you>
Codespace                ✓  your-codespace (Available)
DSH                      ✓  0.1.7-rc.2 (/home/codespace/.nvm/versions/node/v22.x.y/bin)
SSH key                  ✓  ~/.ssh/dsh_cs_key (readable, ssh-ed25519)
Workspace                ✓  clean, HEAD=1a2b3c4 (matches remote)
Deploy key               ✓  ed25519, read/write to <your-repo>
Auto sync                ✓  daemon pid 90277 · mode idle · last log …
Sync config              ✓  mode=idle · idle 600s · squash 1800s
dsh web                  ✓  listening on 127.0.0.1:3080, token required (401 = good)
Tunnel                   ✓  127.0.0.1:3080 → 401 (token required = good)
Launcher                 ✓  desktop has DeepSeek Harness / dsh control panel

12/12 checks passed
```

- `✓` fine · `!` warning (usable, worth a look) · `✗` broken (the line tells you what to do)
- Exit code is 1 when anything is `✗`
- Per-check fixes: [docs/en/doctor.md](docs/en/doctor.md)

---

## Troubleshooting

Start with the [English troubleshooting page](docs/en/troubleshooting.md) (symptoms → cause → fix), or run
`dsh-codespaces doctor` and read the failing line.

Common ones: the `*.app.github.dev` URL doesn't work · `Permission denied` for an SSH key · Chinese text
becomes `????` in `.bat` files · the workspace never syncs · dsh says *authentication required*.

---

## What's in this repo

| Path | Contents |
| --- | --- |
| `README.md` / `README.en.md` | This guide (Chinese / English) |
| `install/` | One-shot installer: `setup.ps1` / `setup.sh` / `cloud-setup.sh`, plus `doctor`, `status`, `audit`, `repair`, `update`, `uninstall` |
| `docs/en/` | English docs (this page links into it) |
| `docs/` | Chinese docs |
| `plugins/dsh-codespace-panel/` | dsh plugin: Codespaces quota panel |
| `plugins/dsh-sync-panel/` | dsh plugin: auto-sync panel |
| `tools/` | `restart-dsh.sh`, `squash-autosync.sh` |
| `VERSION` / `CHANGELOG.md` | Version and changelog |

Docs website: <https://wz2-z.github.io/dsh-codespaces-kit/en/>

---

**One-line summary**: agent in the cloud, tunnel to your machine, repo as backup, scripts for automation.
Run the [installer](install/) or hand the [task book](docs/en/ai-prompt.md) to your AI.

## License

- **Code** (`install/`, `plugins/`, `tools/`): [MIT](LICENSE)
- **Docs**: [CC BY 4.0](LICENSE-docs) — copy, modify, redistribute, just keep the attribution.

- **Author**: [@Wz2-z](https://github.com/Wz2-z)
