# 在 macOS / Linux 本机上使用

```bash
brew install gh            # 或 sudo apt install gh
gh auth login --hostname github.com --git-protocol https --web --scopes codespace,repo,read:org,workflow
ssh-keygen -t ed25519 -N "" -f ~/.ssh/dsh_cs_key -C dsh-codespace
gh codespace ssh -c <名称> -- -i ~/.ssh/dsh_cs_key "bash /workspaces/<repo>/.dsh-cloud/start.sh"
gh codespace ports forward 3080:3080 -c <名称> &     # 保持在后台运行
# 打开上一条命令最后一行打印的 http://127.0.0.1:3080/?token=... 地址
```

---

[← 回到 README](../README.md)
