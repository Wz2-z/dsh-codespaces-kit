# Auto sync

[← English docs](index.md) · [中文](../auto-sync.md)

The container commits and pushes your workspace automatically — but **after the edits stop**, not on a fixed
timer. So the history reads like a series of meaningful commits instead of a wall of `auto sync`.

## Defaults

| Setting | Default | Meaning |
| --- | --- | --- |
| `enabled` | `on` | master switch |
| `mode` | `idle` | smart batching |
| `idle_seconds` | `600` | commit once the tree has been quiet for 10 minutes |
| `max_wait` | `1800` | even during continuous edits, commit at least every 30 minutes |
| `tick` | `30` | how often the daemon looks |
| `prefix` | `dsh` | commit message prefix |
| `squash_window_seconds` | `0` | fold into the previous auto-commit (off by default) |

```
edit edit edit II edit edit      ← the agent keeps working
               └──────────────┘  quiet for 10 minutes
                              ↓
                    one commit (message derived from the diff)
```

## Commit messages

Generated as `prefix: verb paths (N files)`:

| Situation | Message |
| --- | --- |
| 12 files changed under `projects/plugincreate` | `dsh: update projects/plugincreate (12 files)` |
| only additions | `dsh: add notes (3 files)` |
| only deletions | `dsh: remove tools/old (2 files)` |

The body lists the file names. Want a better subject? Two options:

1. **Let the agent write it**: add this to your repo's `AGENTS.md` —

   ```markdown
   ## Wrap-up
   When a task is done, write the commit subject to `.dsh-cloud/commit-msg`
   (one line, e.g. `feat: quota progress bar in the panel`), then finish normally.
   Auto sync uses it as the commit message.
   ```

2. **Set it by hand for the next commit**: `bash .dsh-cloud/sync.sh --message="fix: login 401"`

## Three modes

| Mode | When it commits | Good for |
| --- | --- | --- |
| `idle` (default) | after `idle_seconds` of quiet | almost everyone |
| `interval` | every `interval` seconds | people who want a fixed heartbeat |
| `manual` | only when you run `--now` | full control |

```bash
bash /workspaces/<repo>/.dsh-cloud/sync.sh --mode=interval --interval=300
bash /workspaces/<repo>/.dsh-cloud/sync.sh --mode=idle --idle=600
bash /workspaces/<repo>/.dsh-cloud/sync.sh --mode=manual
```

## Commands

| I want to… | Command |
| --- | --- |
| see mode / pending | `bash .dsh-cloud/sync.sh --status` |
| preview what would be committed | `bash .dsh-cloud/sync.sh --plan` |
| commit right now | `bash .dsh-cloud/sync.sh --now` |
| pause (changes stay in the workspace) | `bash .dsh-cloud/sync.sh --disable` |
| resume | `bash .dsh-cloud/sync.sh --enable` |
| recent sync activity | `tail -n 20 ~/dsh-sync.log` |

## Where the control panel lives

There is **no GUI** for sync itself, but three ways to see it:

1. the `dsh-sync-panel` plugin (a sync button in the dsh sidebar),
2. the Windows control panel in the kit (`install\console.bat` → `[4] auto sync`): status / commit now / pause /
   resume / the three modes / the fold window,
3. the CLI above, inside the container.

Log line meanings: `pushed` (pushed), `folded into previous auto-commit`, `skipped` (a run with no net change),
`push FAILED`.

## Fold window (optional)

With `squash_window_seconds` set (e.g. `1800`), a new commit **folds into the previous one** when that previous
commit is also an auto-commit and is still inside the window. It rewrites history, so pushes use
`--force-with-lease`; if the remote moved (another machine pushed), it falls back to a normal commit.
Keep it off if you use several machines.

## Cleaning up old history

If you ran an older version that committed every N minutes, collapse those commits:

```bash
bash tools/squash-autosync.sh                   # preview
bash tools/squash-autosync.sh --apply           # rewrite locally (creates a backup branch)
bash tools/squash-autosync.sh --apply --push    # also force-with-lease push
```

Only *consecutive* auto-commits are merged; manual commits are left alone, and the tool verifies that the final
file tree is byte-identical before pushing.

## Nothing gets lost

- `max_wait` guarantees a commit at least every 30 minutes during continuous work.
- When a push is rejected it does `pull --rebase` and retries; if that fails the changes stay in the workspace.
- The real backup is still your **remote repo**: `~/dsh-workspace` is just a clone on a persistent volume.
