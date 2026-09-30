# dsh-codespaces doctor

[← English docs](index.md) · [中文](../doctor.md)

Run it after installing, on a new machine, or whenever something feels off:

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File install\doctor.ps1
```

```bash
# macOS / Linux
bash install/doctor.sh
```

It merges **host-side** and **container-side** checks into one table and ends with `N/M checks passed`.

## The 12 checks

| Check | Side | ✓ means | Usual fix |
| --- | --- | --- | --- |
| GitHub CLI | host | `gh` found, version printed | `install/setup.ps1` installs a portable copy; or `brew install gh` |
| GitHub authentication | host | `gh auth status` succeeds | `gh auth login --scopes codespace,repo,read:org,workflow` |
| Codespace | host | a usable Codespace exists | `gh codespace create -R owner/repo` (or `dsh-codespaces setup`) |
| DSH | container | dsh found, version printed | run `install/cloud-setup.sh` |
| SSH key | host | private key exists **and** `ssh-keygen` can read it | regenerate it **as the user**; on Windows fix the ACL with `icacls` |
| Workspace | container | clean, HEAD matches remote | wait for auto sync, or `sync.sh --now` |
| Deploy key | container | `~/.ssh/dsh_deploy` can read/write the repo | add the public key under repo Settings → Deploy keys (write access) |
| Auto sync | container | daemon running and not paused | `bash .dsh-cloud/start.sh`; if paused, `sync.sh --enable` |
| Sync config | container | `sync.conf` has a valid mode | run `cloud-setup.sh` to (re)generate |
| dsh web | container | port 3080 listening and requires a token (401) | `bash .dsh-cloud/start.sh`; see `~/dsh-web.log` |
| Tunnel | host | `127.0.0.1:3080` answers | double-click the start launcher, or `gh codespace ports forward 3080:3080` |
| Launcher | host | desktop shortcuts exist (and their targets exist) | re-run `install/setup.ps1` / `setup.sh` |

## Reading the three states

- `✓` **ok** — nothing to do
- `!` **warn** — usable, but worth a look (e.g. "auto sync is paused", "network is down so the token wasn't verified")
- `✗` **fail** — broken; the line usually says what to do next

Exit code is 0 with no `✗`, 1 otherwise (handy in scripts/CI).

## Flags

| Flag | Effect |
| --- | --- |
| `-Base <dir>` (Windows) | where everything lives (expects `gh\bin\gh.exe` and `ghconfig\`) |
| `-Gh <path>` / `-Key <path>` | point at a specific gh / private key |
| `-NoTunnel` / `--no-tunnel` | skip the tunnel probe (faster) |
| `-Json` / `--json` | machine-readable output |

## What it does *not* do

It never changes configuration, restarts dsh, or commits anything. The only side effect is the tunnel probe,
which opens a port forward, checks it, and closes it again.

## Two Windows gotchas worth knowing

1. **`.bat` files must use CRLF line endings.** With LF endings, `goto label` fails with
   *"The system cannot find the batch label specified"*.
2. **Chinese/UTF-8 output needs `chcp 65001`.** Container scripts emit UTF-8; a Chinese Windows console
   defaults to codepage 936 and would print mojibake. `.ps1` files must be saved as **UTF-8 with BOM**.
