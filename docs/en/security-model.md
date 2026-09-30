# Security model: what this tool actually creates

[← English docs](index.md) · [中文](../security-model.md)

Short version: **no account-level PAT, no GitHub App, no cloud-provider account, no sudo changes.** It puts two
things on your machine (a portable gh and one SSH key), one per-repo deploy key in the container, and everything
else lives inside GitHub's own mechanisms.

Check the live state any time:

```
dsh-codespaces audit        # credential/permission inventory (never prints key material)
dsh-codespaces audit -Json  # for scripts
```

## What exists

| Thing | Where | What it can do | How to revoke |
| --- | --- | --- | --- |
| **Portable GitHub CLI** | host `%LOCALAPPDATA%\dsh-cloud\gh\` (or `~/.local/share/dsh-cloud`) | just an executable: not installed system-wide, not on `PATH`, no admin | delete the folder (`uninstall -Yes -PurgeLocal`) |
| **GitHub login token** | host, inside gh's config dir (`ghconfig\hosts.yml`, **plaintext**) | anything your GitHub account can do: read/write your repos, manage your Codespaces | `gh auth logout -h github.com`, or revoke it under GitHub → Settings → Applications |
| **SSH private key** `dsh_cs_key` | host `%USERPROFILE%\.ssh\` | **only** SSH into your own Codespace — no repo access, no settings | delete both files locally; remove the public key under GitHub → Settings → SSH and GPG keys |
| **deploy key** `dsh_deploy` | container `~/.ssh/` (public half registered on **your repo**) | **write access to that one repo** (used for auto sync) | repo Settings → Deploy keys → delete `dsh-cloud-autosync`, or `uninstall -Yes -Cloud -RevokeDeployKey` |
| **Codespaces platform token** | container `/workspaces/.codespaces/shared/.env` (put there by GitHub) | git/gh inside the container use it; dies with the container | nothing to revoke |
| **DeepSeek API key** | container `~/.dsh/.credentials.yaml` (mode 0600) | only dsh inside the container uses it; never pushed anywhere | revoke it in the DeepSeek console; the file disappears with the Codespace |
| **Sync config** `.dsh-cloud/` | container `/workspaces/<repo>/.dsh-cloud/` (persistent volume) | `start.sh` / `update.sh` / `sync.sh` / `sync.conf`, **no credentials** | `uninstall -Yes -Cloud -PurgeCloud` |
| **Desktop shortcuts + `.bat`** | host desktop and the workspace `outputs\` | launchers only, **no secrets** (paths and a Codespace name) | `uninstall -Yes -Local` |

## What does *not* exist

- ❌ Account-level PAT (the one the optional quota panel stores is read-only-ish and stays in dsh's credential store)
- ❌ GitHub App / OAuth App / any third-party authorization
- ❌ Cloud provider account (AWS/GCP/…) — there is no server, only GitHub Codespaces
- ❌ System changes: no system directories, no `PATH` edits, no admin/root, no global installs (outside the container)

## Who can see what

| Place | Can see | Cannot see |
| --- | --- | --- |
| your computer | portable gh, gh token, SSH private key, launchers | DeepSeek API key, deploy key private half |
| the Codespace container | deploy key, DeepSeek API key, platform token, `.dsh-cloud` scripts | your host SSH key, your host gh token |
| your GitHub account | Codespaces, the deploy key's public half, gh's authorization | your DeepSeek API key |
| your repo (remote) | whatever you push | any key (unless you commit one yourself) |

## Risk boundaries

- **The agent runs in the container**: it can read everything there, including the DeepSeek key and the deploy
  key. Do not put other credentials in the container.
- **Never put secrets in the workspace** — everything in `~/dsh-workspace` is pushed to the repo.
- **Plugins get host permissions**: they run in the same process and can read container files. Check the source;
  try unknown ones under `read-only` first.
- **gh's token is stored in plaintext** on the host. For a stronger setup use the OS keyring during
  `gh auth login`, or `gh auth logout` when you're done.

## Revoke / uninstall

```bash
dsh-codespaces uninstall                                   # preview only
dsh-codespaces uninstall -Yes -Local -Cloud                # delete shortcuts, stop cloud services
dsh-codespaces uninstall -Yes -Cloud -PurgeCloud -RevokeDeployKey
dsh-codespaces uninstall -Yes -Local -PurgeLocal -Cloud -DeleteCodespace   # full wipe (irreversible)
```

It always lists what it will and will not touch; the default is always a preview.
