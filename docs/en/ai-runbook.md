# Technical runbook (for the AI)

[← English docs](index.md) · [中文](../ai-runbook.md)

This page is the execution detail behind the [task book](ai-prompt.md). A human does not need to read it.

## 1. Inside the container

```bash
# 1) Node 22 + dsh (Codespaces keeps nvm under /usr/local/share/nvm)
export NVM_DIR=/usr/local/share/nvm; . $NVM_DIR/nvm.sh
nvm install 22 && nvm alias default 22
npm install -g @deepseek-ai/dsh
node -v && dsh --version

# 2) the workspace is a clone of the private repo
cd ~ && git clone git@github.com:<you>/<repo>.git dsh-workspace

# 3) scripts live on the persistent volume
mkdir -p /workspaces/<repo>/.dsh-cloud
# start.sh / update.sh / sync.sh / sync.conf — see install/cloud-setup.sh
```

**Deploy key (write access to that one repo only)**

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/dsh_deploy -C dsh-deploy
cat ~/.ssh/dsh_deploy.pub
# add it under repo Settings -> Deploy keys with "Allow write access"
# or: gh api -X POST /repos/<you>/<repo>/keys -f title="dsh-cloud-autosync" \
#        -f key="<public key>" -F read_only=false
cd ~/dsh-workspace
git config core.sshCommand "ssh -i $HOME/.ssh/dsh_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
git config user.name "dsh cloud"
git config user.email "dsh-cloud@users.noreply.github.com"
```

**dsh permission presets** (append to `~/.dsh/profiles/web/cordis.patch.yml`)

```yaml
- id: sandbox-policy
  name: "@deepseek-ai/dsh-sandbox-policy"
  config:
    mode: workspace-write
    workspaceRoot: !!js process.cwd()
- id: approval
  name: "@deepseek-ai/dsh-user-approval"
  config:
    policy: ask
- id: permission
  name: "@deepseek-ai/dsh-permission-presets"
  config:
    defaultPreset: workspace-write
    presets:
      read-only:        { sandbox: read-only,        approval: ask }
      workspace-write:  { sandbox: workspace-write,  approval: ask }
      danger-full-access: { sandbox: danger-full-access, approval: ask }
```

## 2. On the host (Windows)

```bat
:: portable gh (no admin needed)
set "DIR=%LOCALAPPDATA%\dsh-cloud"
curl.exe -sL -o "%DIR%\gh.zip" https://github.com/cli/cli/releases/download/vX.Y.Z/gh_X.Y.Z_windows_amd64.zip
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%DIR%\gh.zip' -DestinationPath '%DIR%\gh' -Force"

:: one-time authorization (needs the codespace scope)
"%DIR%\gh\bin\gh.exe" auth login --hostname github.com --git-protocol https --web --scopes codespace,repo,read:org,workflow

:: SSH key (must be created by the current user)
ssh-keygen -t ed25519 -N "" -f "%USERPROFILE%\.ssh\dsh_cs_key" -C dsh-codespace

:: start dsh in the cloud (the last line prints the token URL)
"%DIR%\gh\bin\gh.exe" codespace ssh -c <codespace> -- -i "%USERPROFILE%\.ssh\dsh_cs_key" "bash /workspaces/<repo>/.dsh-cloud/start.sh"

:: tunnel (keep this window open)
start "dsh tunnel" /min cmd /c ""%DIR%\gh\bin\gh.exe" codespace ports forward 3080:3080 -c <codespace>"
```

macOS/Linux equivalents: [macos-linux.md](macos-linux.md).

## 3. Acceptance criteria

| Check | Expected |
| --- | --- |
| cloud dsh process | `ss -ltn` shows `:3080` listening |
| request without token | **401** |
| request with token | **303** plus a `dsh-auth-*` cookie |
| local tunnel | `curl http://127.0.0.1:3080/` returns 401 (proves the tunnel works) |
| browser | the token URL opens the dsh UI |
| git backup | local `HEAD` == `git ls-remote origin refs/heads/main` |
| empty dirs | a new empty folder shows up (with `.gitkeep`) after the tree goes quiet |
