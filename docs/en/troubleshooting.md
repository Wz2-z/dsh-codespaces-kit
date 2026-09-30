# Troubleshooting

[← English docs](index.md) · [中文](../troubleshooting/windows.md)

Everything here is written as **symptom → cause → fix**. If a check fails, `dsh-codespaces doctor` usually tells
you which of these applies.

## The GitHub port-forwarding URL does not work

**Symptom** — you set port 3080 to Public/Private and open `https://xxx-3080.app.github.dev`, and see:

```
dsh web authentication required; reopen the URL printed by dsh web.
```

**Cause** — dsh binds its session cookie to the authority `127.0.0.1:3080`; a different hostname never matches.

**Fix** — forward the port locally and open the URL dsh printed:

```bash
gh codespace ports forward 3080:3080 -c <codespace-name>     # keep this window open
gh codespace ssh -c <codespace-name> -- -i <key> "bash /workspaces/<repo>/.dsh-cloud/start.sh"
# then open http://127.0.0.1:3080/?token=...
```

## `Load key ...: Permission denied`

**Cause** — the private key was created by another user (or an agent sandbox), so Windows OpenSSH refuses to load it.

**Fix** — generate it **as the person using the machine**:

```bat
ssh-keygen -t ed25519 -N "" -f "%USERPROFILE%\.ssh\dsh_cs_key" -C dsh-codespace
icacls "%USERPROFILE%\.ssh\dsh_cs_key" /inheritance:r /grant:r "%USERNAME%:R"
```

## Chinese text becomes `????` in `.bat` files

**Symptom**

```
FINDSTR: cannot open C:\Users\<you>\...\dsh????.txt
```

**Cause** — a `.bat` saved as ASCII mangles non-ASCII filenames; a `%USERPROFILE%` containing non-ASCII
characters makes redirection fail outright.

**Fix** — keep `.bat` files **pure ASCII** (comments, log names, everything), always build paths from
`%USERPROFILE%` / `%LOCALAPPDATA%`, and add `chcp 65001 >nul` when you need to *display* UTF-8 output.

## `.bat` says "The system cannot find the batch label specified"

**Cause** — the file has LF line endings; cmd's `goto`/label handling needs CRLF.

**Fix** — save the `.bat` with CRLF endings (and keep it ASCII).

## "dsh can't see images" — it's the model, not the app

| Model | Input modality | Result |
| --- | --- | --- |
| `deepseek-flash` | text + image | can read images |
| `deepseek-v4-pro` | text | text only |

Switch models. Only custom/proxy vision models need Settings → Models → custom → model options → input types
(stored as `input` / `inputModalities`).

## The container lost its environment after a rebuild

**Cause** — `/workspaces` is persistent, `$HOME` is not. Rebuilding the container wipes dsh, `~/.dsh`
history and the deploy key.

**Fix** — keep scripts in `/workspaces/<repo>/.dsh-cloud/`, push your work, and re-run
`dsh-codespaces repair` (or `install/cloud-setup.sh`) after a rebuild.

## `pkill -f "dsh web"` kills your own shell

**Cause** — the command string itself contains `dsh web`, so `pkill -f` matches its own process
(you see `shell closed: exit status 0xffffffff`).

**Fix** — find the PID by port and kill that:

```bash
PID=$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
[ -n "$PID" ] && kill "$PID"
```

## A long command gets truncated over SSH

**Symptom** — `syntax error near unexpected token '('` when pasting a big script.

**Cause** — a PTY connection truncates very long one-shot commands.

**Fix** — write the script to a file (base64 works well) and run it, without a TTY.

## Empty folders never show up in the repo

**Cause** — git does not track empty directories.

**Fix** — the sync script drops a `.gitkeep` into empty directories (skipping ignored paths). Manual sync:
`bash .dsh-cloud/sync.sh --now`.

## `~/.nvm/nvm.sh` does not exist in Codespaces

**Cause** — Codespaces ships nvm under `/usr/local/share/nvm`.

**Fix** — use absolute paths, or probe several locations:

```bash
for d in "$HOME/.nvm/versions/node"/*/bin /usr/local/share/nvm/versions/node/*/bin; do
  [ -x "$d/dsh" ] && { export PATH="$d:$PATH"; break; }
done
```

## The sidebar button for a plugin never appears

1. Is the plugin in `dsh.profile.bundles` in `~/.dsh/profiles/web/package.json`?
2. Did you restart dsh (`tools/restart-dsh.sh`)?
3. Hard-refresh the page (`Ctrl+Shift+R`).
4. Check dsh's startup log for a loader error — a row that fails to activate can also break other plugins'
   settings forms until the page/host restarts.
