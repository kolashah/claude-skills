# Release Notes

## v1.1.0 — 2026-04-14

- **Fix `clean` to reconcile PR statuses first** — `clean` now checks `pr open` items via GitHub API before filtering, so freshly-merged PRs are caught in the same invocation instead of requiring a separate `list` call
- **Auto-execute enforcement** — `list`, `status`, and `watch` now immediately trigger execution when an `auto-execute` verdict is discovered, without asking for confirmation
- **Semantic branch names for batch execute** — branch names are now generated from todo descriptions (e.g., `jane/sticky-page-tabs`) instead of generic `jane/crm-todo-3`
- **Executor worktree cleanup** — executor agent now removes its worktree after pushing the PR, unblocking branch checkout in the main repo

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
