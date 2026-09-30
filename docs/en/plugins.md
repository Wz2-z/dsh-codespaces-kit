# Plugins

[← English docs](index.md) · [中文](../plugins.md)

dsh plugins run **inside the host process**, with the same permissions as your container account. So the rule is:
install only what you can read and understand; try anything uncertain under `read-only` first.

## dsh-codespace-panel (quota + one-click stop)

Full description: [`plugins/dsh-codespace-panel/`](https://github.com/Wz2-z/dsh-codespaces-kit/tree/main/plugins/dsh-codespace-panel).

```bash
# run this inside YOUR Codespace container, not on your computer
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-codespace-panel
# then add "dsh-codespace-panel" to dsh.profile.bundles in package.json
```

Restart dsh (`dsh web`, or `tools/restart-dsh.sh`) and refresh the page — a battery icon appears at the bottom
of the sidebar. The quota numbers need a **classic PAT with `user` scope** pasted into the panel (stored in
`$DSH_HOME/.credentials.yaml`, mode 0600, never committed); the Codespace state/stop button uses the container's
own platform token and needs no setup.

## dsh-sync-panel (auto-sync status)

A separate plugin — install either one, or both. It shows mode, paused/running, daemon state, pending files,
last commit, the fold window and the tail of `~/dsh-sync.log`, and offers commit-now / pause / resume /
switch mode / toggle fold.

```bash
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-sync-panel
# add "dsh-sync-panel" to dsh.profile.bundles
```

Details: [`plugins/dsh-sync-panel/`](https://github.com/Wz2-z/dsh-codespaces-kit/tree/main/plugins/dsh-sync-panel).

## Three questions before installing any plugin

1. Can it read my API key or private keys? (`~/.dsh/.credentials.yaml`, `~/.ssh`)
2. Will it write into the repo? (everything in the workspace gets pushed)
3. Can I remove it? — `pnpm remove <name>` plus deleting its line from `dsh.profile.bundles`

Plugin errors usually show up in dsh's startup log; if a sidebar button never appears, see the
[troubleshooting page](troubleshooting.md).
