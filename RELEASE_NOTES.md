# Release Notes

## v1.0.0 — 2026-03-19

Initial shared release.

- **Three-agent pipeline** — planner, executor, and reviewer agents run in background
- **Cross-repo support** — configure repo shorthands in `~/.claude/todo-config.json`
- **Batch execution** — execute multiple tasks in parallel worktrees
- **Watch mode** — monitor a task and get notified on state changes
- **Review with overrides** — triage PR comments with `--dry-run`, override verdicts with `fix:N dismiss:N`
- **Stale detection** — stuck planners auto-reset after 15min, stuck executors get warnings after 30min
- **Worktree cleanup** — `cancel`, `remove`, and `clean` properly remove git worktrees
- **`/minion pr`** — contribute skill improvements via PR directly from the CLI
