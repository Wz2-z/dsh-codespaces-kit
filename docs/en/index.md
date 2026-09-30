---
title: dsh on GitHub Codespaces — English
---

# dsh on GitHub Codespaces — English docs

Run the official DeepSeek Harness (dsh) in a GitHub Codespace, reach it from your own machine through one SSH
tunnel, and keep the workspace backed up in your own private repo.

> 中文读者：这页的对应中文版在 [docs/](../)（[主 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md)）。

## Start here

- [Main README (English)](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.en.md) — 30-second overview → install → configure → daily use
- [One-shot installer](https://github.com/Wz2-z/dsh-codespaces-kit/tree/main/install) — `setup.ps1` / `setup.sh`, ends with `✅ Installation complete`
- [Checkup: doctor](doctor.md) — the 12 checks and what to do when one fails
- [Lifecycle](lifecycle.md) — `status` / `setup` / `repair` / `update` / `uninstall`
- [Security model](security-model.md) — every key/token/config this tool creates, what it can do, how to revoke it

## Go deeper

- [Auto sync](auto-sync.md) — idle debounce, three modes, generated commit messages, fold window
- [Plugins](plugins.md) — quota panel and sync panel for the dsh sidebar
- [Troubleshooting](troubleshooting.md) — symptoms → cause → fix (Windows, SSH, Codespaces, dsh)
- [Task book for your AI](ai-prompt.md) — copy one block and let an agent do the install
- [Technical runbook](ai-runbook.md) · [Cloud scripts](cloud-scripts.md) · [macOS / Linux](macos-linux.md) · [Directory layout](directory-layout.md)

---

[GitHub repo](https://github.com/Wz2-z/dsh-codespaces-kit) · MIT / CC BY 4.0 · [@Wz2-z](https://github.com/Wz2-z)
