# Using it from macOS / Linux

[← English docs](index.md) · [中文](../macos-linux.md)

```bash
brew install gh            # or sudo apt install gh
gh auth login --hostname github.com --git-protocol https --web --scopes codespace,repo,read:org,workflow
ssh-keygen -t ed25519 -N "" -f ~/.ssh/dsh_cs_key -C dsh-codespace
gh codespace ssh -c <codespace-name> -- -i ~/.ssh/dsh_cs_key "bash /workspaces/<repo>/.dsh-cloud/start.sh"
gh codespace ports forward 3080:3080 -c <codespace-name> &     # keep running
# open the http://127.0.0.1:3080/?token=... URL printed by the previous command
```

Or just run the installer, which also creates desktop launchers:

```bash
bash install/setup.sh --repo=your-name/your-repo
```
