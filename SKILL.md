---
name: minion
description: Manage a cross-repo todo list with background planning agents. Add tasks, track status, get plans created automatically.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
---

# Todo List Manager

Persistent todo list at `~/.claude/todos.json`. Parse command from `$ARGUMENTS`. Default to `list` if empty. If `$ARGUMENTS` is `help` or `--help` or `-h`, show the help output below and stop.

**Flexible argument order:** Users may put the command and ID in any order (e.g., `review 16`, `16 review`, `status 3`, `3 status`). When parsing `$ARGUMENTS`, identify the command keyword and the numeric ID regardless of position. For commands that take additional args (e.g., `execute <id> <branch>`, `update <id> <note>`, `chat <id> <message>`), the ID and command keyword can still be in either order — everything else is the remaining arguments.

## Bootstrap

On **every invocation**, before processing any command, resolve these runtime values silently (no output to user):

1. **`$HOME_DIR`** — run `echo $HOME` via Bash to get the user's home directory (e.g., `/Users/jane`). All file paths use this.
2. **`$GIT_USER`** — run `git config user.name` or fall back to `whoami`. Used for branch name prefixes.
3. **`$TODO_CONFIG`** — read `$HOME_DIR/.claude/todo-config.json` if it exists. Contains repo shorthands. If missing, tell user: "Run the setup script first: `bash ~/.claude/skills/minion/setup.sh`" and stop.
4. **File paths** — derive from `$HOME_DIR`:
   - JSON: `$HOME_DIR/.claude/todos.json`
   - Plans dir: `$HOME_DIR/.claude/todo-plans/`
   - Config: `$HOME_DIR/.claude/todo-config.json`

**CRITICAL: Always use the resolved absolute `$HOME_DIR` paths** (e.g., `/Users/jane/.claude/todos.json`), never `~/.claude/` or relative paths. This is required for permission auto-approval.

5. **Auto-update check** — read `$HOME_DIR/.claude/todo-last-seen-version`. This file has two lines: the version string and a Unix timestamp of the last pull. If the timestamp is missing or older than **1 hour**, run a silent update:
   - `cd` into the skill repo directory (resolve symlink target of `${CLAUDE_SKILL_DIR}` if needed).
   - Run `git pull --ff-only origin main 2>/dev/null` silently. If it fails (e.g., local changes, merge conflict), skip — don't block the user.
   - After pulling, compare the latest `## vX.Y.Z` in `RELEASE_NOTES.md` against the stored version. If different:
     - Extract everything under the latest `## vX.Y.Z` heading (stop at the next `## ` or end of file).
     - Display: `**🆕 /minion updated to vX.Y.Z:**` followed by the notes.
   - Write the new version string and current Unix timestamp to `$HOME_DIR/.claude/todo-last-seen-version` (two lines: version on line 1, timestamp on line 2).
   - If the timestamp is fresh (< 1 hour old) and version matches, skip everything silently.

Cache these values for the duration of the conversation — only resolve once.

## Help Output

When help is requested, first read `$HOME_DIR/.claude/todo-config.json` to get the user's configured repo shorthands, then display:

```
/minion — Cross-repo todo list with background planning & execution

Commands:
  add <repo> <description>        Add a task and auto-plan in background
  list                            Show all todos with status table
  status <id>                     Show full details, plan, and PR link
  update <id> <note>              Add context/notes to a task
  done <id>                       Mark complete
  remove <id>                     Delete a task and its plan files
  plan <id>                       Re-run the background planner
  execute <id> <branch> [base]    Implement plan in a worktree, push, and open PR
  chat <id> <message>              Ask questions about a todo's plan, context, or codebase
  review <id> [--dry-run] [fix:N dismiss:N]  Auto-address PR review comments
  batch execute <ids> [base]       Execute multiple todos in parallel worktrees
  watch <id>                       Monitor a todo and notify on state changes
  config                            Show or update settings
  pr                               Commit and PR any local skill changes
  cancel <id>                     Close PR and mark as cancelled
  clean                           Remove all completed and cancelled tasks
  help                            Show this help

Repo shorthands (from ~/.claude/todo-config.json):
  <dynamically list the user's configured shorthands>

Status flow:
  not started → planning... → plan ready → in progress → pr open → complete
                                                                 ↳ cancelled

Examples:
  /minion add crm make page tabs sticky
  /minion execute 3 my-feature-branch
  /minion execute 3 my-feature-branch release/1.5.0
  /minion status 3
  /minion chat 2 tell me about the architectural tradeoffs
  /minion batch execute 3,4,5 release/1.5.0
  /minion watch 3

Tip: Run /loop 5m /minion list for periodic status updates.
```

## Commands

| Command | Example |
|---------|---------|
| `add <repo> <description>` | `/minion add crm add rate limiting to the users endpoint` |
| `list` | `/minion list` |
| `status <id>` | `/minion status 3` |
| `update <id> <note>` | `/minion update 3 only affects settings page` |
| `done <id>` | `/minion done 3` |
| `remove <id>` | `/minion remove 3` |
| `plan <id>` | `/minion plan 3` (re-run planner) |
| `execute <id> <branch> [base]` | `/minion execute 3 my-feature-branch release/1.5.0` |
| `chat <id> <message>` | `/minion chat 2 what tradeoffs did you consider` |
| `review <id> [--dry-run] [fix:N dismiss:N]` | `/minion review 2 --dry-run` or `/minion review 2 fix:2 dismiss:3` |
| `batch execute <ids> [base]` | `/minion batch execute 3,4,5 release/1.5.0` |
| `watch <id>` | `/minion watch 3` |
| `config [key] [value]` | `/minion config` or `/minion config squashCommits true` |
| `pr` | `/minion pr` |
| `cancel <id>` | `/minion cancel 3` |
| `clean` | `/minion clean` |

## Repos

Repo resolution order when parsing the first argument of `add`:
1. **Config shorthands** — look up in `$HOME_DIR/.claude/todo-config.json` `repos` object. Each key maps to an absolute path.
2. **Absolute path** — if the argument starts with `/`, use it directly (verify it exists).
3. **Error** — if no match, tell the user: "Unknown repo `<name>`. Add it to `~/.claude/todo-config.json` or pass an absolute path."

## Config

`$HOME_DIR/.claude/todo-config.json` supports these fields:

```json
{
  "repos": {
    "shorthand": "/absolute/path/to/repo"
  },
  "squashCommits": false
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `repos` | required | Map of shorthand names to absolute repo paths |
| `squashCommits` | `false` | When `true`, follow-up changes and review fixes amend the existing commit and force-push. When `false`, creates new commits and pushes normally. |

Read `squashCommits` from the config during bootstrap and pass it as `{squashCommits}` when filling executor and reviewer prompt templates.

## Storage

`$HOME_DIR/.claude/todos.json` — fields: `id`, `description`, `repo`, `repoPath`, `status`, `created`, `updated`, `notes[]`, `verdict`, `branch`, `baseBranch`, `worktreePath`, `pr`, `needsReview`, `lastReviewCheck`. Auto-increment `nextId`. Create file with `{"nextId": 1, "todos": []}` if missing.

Plan and result files are always at `$HOME_DIR/.claude/todo-plans/plan-{id}.md`, `result-{id}.md`, and `review-{id}.md` — derived from the todo's `id`, never stored as a field.

**Statuses:** `not started` → `planning...` → `plan ready` → `in progress` → `pr open` → `complete`

## Rules

- **CRITICAL: Always use the resolved absolute `$HOME_DIR` paths** for all todo files (e.g., `/Users/jane/.claude/todos.json`), never `~/.claude/` or relative paths. This is required for permission auto-approval to work.
- Always read the todos JSON before any operation.
- Only write JSON if something actually changed (status, notes, verdict, PR URL, needsReview). Do NOT write just to update `updated` or `lastReviewCheck` timestamps if nothing else changed.
- Timestamps in US Eastern (America/New_York). Display as "Mar 18 14:30 ET".
- Keep output concise.
- **Minimize tool calls:** Batch operations where possible. Get the timestamp via Bash inline with other work instead of a separate call. Read the JSON and template files in parallel. Do NOT narrate intermediate steps like "Let me read the file" or "Now updating the JSON" — just do it silently and show the final result/table to the user.
- **Fast-path for simple commands:** `done`, `update`, `remove`, `clean`, and `help` do NOT need status reconciliation. Read JSON, mutate, write, display. Skip all file/API checks.
- **Throttle API calls:** For `pr open` items, only check GitHub API if `lastReviewCheck` is older than 10 minutes. This prevents `/loop` from hammering the API.

## Command Details

### `add`
1. Parse repo (first word) + description (everything after repo). Resolve repo path using the resolution order above.
2. If task is ambiguous, ask 1-2 brief scoping questions. Skip if already clear.
3. Save todo with status `not started`, scoping answers in `notes`.
4. Display table, then set status `planning...` and spawn background planner (see Agents).
5. First time per conversation, mention: "Tip: Run `/loop 5m /minion list` for periodic updates."

### `list`
Render markdown table: `ID | Repo | Description | Status | Branch / PR | Created`

**Speed is critical for `list`.** Minimize tool calls. Skip items with terminal statuses (`complete`, `cancelled`). Batch everything into as few calls as possible.

Reconcile only non-terminal statuses in **one parallel batch**:
1. Collect all items that need checks. Build a single Bash command that runs all file existence checks and `gh` API calls concurrently with `&` and `wait`, outputting results as **labeled lines** with a consistent prefix format: `CHECK:<id>:<check_type>:<result>`. Each check should be wrapped so failures produce a labeled error line (`CHECK:<id>:<check_type>:ERROR:<message>`) rather than corrupting other output. Example:
   ```bash
   (test -f /path/plan-3.md && echo "CHECK:3:plan:$(grep -m1 'Verdict:' /path/plan-3.md)" || echo "CHECK:3:plan:NOT_FOUND") &
   (gh pr view <url> --json state -q '.state' 2>/dev/null && echo "CHECK:4:pr:$?" || echo "CHECK:4:pr:ERROR:gh_failed") &
   wait
   ```
2. Parse the labeled output and update statuses. **Ignore any line that doesn't match the `CHECK:` prefix** — this prevents stray stderr or warnings from corrupting results:
   - `planning...` → if plan file exists, read verdict line, update to `plan ready` with verdict (`auto-execute`/`review`/`needs-input`). **Stale detection:** if plan file does NOT exist and `updated` timestamp is older than 15 minutes, reset status to `not started` and append note `[system] Planner timed out — reset to not started`.
   - `in progress` → if result file exists, update to `pr open`, extract PR URL. **Stale detection:** if result file does NOT exist and `updated` timestamp is older than 30 minutes, append note `[system] Executor may be stuck — consider re-running /minion execute`.
   - `pr open` → **always** run `gh pr view` for these items (merge check is never throttled). If `MERGED` → `complete`. If still open, only check `reviews` for `CHANGES_REQUESTED` if `lastReviewCheck` is older than 10 minutes.
3. Write JSON once with all updates.
4. Render table. No narration between steps.

For `auto-execute` verdicts discovered during list: **immediately trigger auto-execution** (see Auto-execute below) after rendering the table. NEVER ask the user for confirmation — just execute it.

Branch/PR column: `—` for not started/planning/plan ready, branch name for in progress, `[PR #N](url)` for pr open/complete. Append ` (review)` if `needsReview` is true.

After table, show one-line actionable hints only for items that need attention.

### `status <id>`
Show full todo details. Same reconciliation as `list` for that item. Display plan contents and/or result file + PR link as applicable. If reconciliation discovers an `auto-execute` verdict, **immediately trigger auto-execution** (see Auto-execute below) after displaying the status. NEVER ask the user — just execute.

### `update <id> <note>`
Append to `notes[]`. Update timestamp.

### `done <id>` / `remove <id>`
Update status or delete. `remove` also deletes associated files in `$HOME_DIR/.claude/todo-plans/`. If the todo has a `worktreePath`, remove the git worktree via `git -C <repoPath> worktree remove <worktreePath> --force` before deleting.

### `clean`
Remove all todos with status `complete` or `cancelled`. Also delete their associated plan, result, and review files from `$HOME_DIR/.claude/todo-plans/`. If a todo has a `worktreePath`, remove the git worktree via `git -C <repoPath> worktree remove <worktreePath> --force` before deleting.

### `batch execute <ids> [base]`
Execute multiple `plan ready` todos in parallel, each in its own worktree.

1. Parse comma-separated IDs (e.g., `3,4,5`). Optional base branch applies to all items that don't already have a `baseBranch`.
2. Validate all items are `plan ready`. Report any that aren't and skip them.
3. For each valid todo, auto-generate a branch name: `$GIT_USER/<repo>-todo-<id>` (e.g., `jane/crm-todo-3`).
4. Set all valid todos to `in progress`, save `branch` and `baseBranch`. Write JSON once.
5. Read the executor prompt template once from `${CLAUDE_SKILL_DIR}/executor-prompt.md`.
6. For each todo, read its plan file and fill the template with its specific context.
7. Spawn **all executor agents in parallel** — each with `run_in_background: true` and `isolation: "worktree"`. Use a single message with multiple Agent tool calls.
8. Display a summary table of what was launched:
   ```
   | ID | Repo | Branch | Base | Status |
   | 3  | crm  | jane/crm-todo-3 | release/1.5.0 | launched |
   | 4  | resident | jane/resident-todo-4 | main | launched |
   | 5  | crm  | jane/crm-todo-5 | release/1.5.0 | skipped (not plan ready) |
   ```
9. Tell user: "Use `/minion list` to check progress."

### `watch <id>`
Monitor a todo and proactively notify when its state changes. Uses `/loop` under the hood.

1. Read the todo and record its current status as the baseline.
2. Start a `/loop 2m` that runs a focused reconciliation check on just this todo:
   - `planning...` → check if plan file exists
   - `in progress` → check if result file exists
   - `pr open` → check if PR merged or has new review comments
3. On each loop iteration, compare against the baseline status. **Only output if something changed:**
   - `planning... → plan ready` with `auto-execute` verdict: **immediately trigger auto-execution** (see Auto-execute below). Output: "Todo #{id} plan ready — auto-executing on branch `{branch}`."
   - `planning... → plan ready` with other verdicts: "Todo #{id} plan is ready (verdict: {verdict}). Run `/minion status {id}` to review, or `/minion execute {id} <branch>` to start."
   - `in progress → pr open`: "Todo #{id} PR created: {pr url}"
   - `pr open → complete`: "Todo #{id} PR merged!"
   - `pr open` + new review comments: "Todo #{id} has new review comments. Run `/minion review {id} --dry-run` to triage."
   - If nothing changed, output nothing (silent iteration).
4. Auto-stop the loop when the todo reaches a terminal status (`complete`, `cancelled`).
5. Update `lastReviewCheck` when checking PR status to stay in sync with throttling rules.

**Implementation:** This command invokes the `/loop` skill internally. The loop body is a mini version of `list` reconciliation scoped to one todo. The key difference from `/loop 5m /minion list` is: (a) faster interval (2m vs 5m), (b) only checks one item, (c) silent when nothing changed, (d) auto-stops on completion.

### `config [key] [value]`
Show or update settings in `$HOME_DIR/.claude/todo-config.json`. Fast-path — no status reconciliation.

- **No args** (`/minion config`): display current config as a formatted table.
- **Key only** (`/minion config squashCommits`): display that setting's current value.
- **Key + value** (`/minion config squashCommits true`): update the setting, write the file, confirm. Boolean values accept `true`/`false`. The `repos` field cannot be set this way — edit the JSON directly.

### `pr`
Commit and open a PR for any local changes to the skill files. Automatically bumps the version and adds release notes.

1. Resolve the skill repo path: the directory that `${CLAUDE_SKILL_DIR}` points to (or its symlink target if it's a symlink).
2. `cd` into the skill repo and run `git status`. If no changes, tell user "No changes to submit" and stop.
3. Show the user a summary of what changed (`git diff --stat`).
4. Ask the user for a short description of the change (one line).
5. **Auto-bump version** — read the latest `## vX.Y.Z` from `RELEASE_NOTES.md`, bump the patch number (e.g., `v1.0.0` → `v1.0.1`). If the changes are significant (new commands, breaking changes), bump minor instead (e.g., `v1.0.0` → `v1.1.0`). Use your judgment based on the diff.
6. **Add release notes** — prepend a new section to `RELEASE_NOTES.md`:
   ```markdown
   ## vX.Y.Z — YYYY-MM-DD

   - Bullet points summarizing the changes (generate from the diff + user's description)
   ```
7. Create a branch: `git checkout -b $GIT_USER/skill-update-$(date +%s)`
8. Stage all changes (including the updated `RELEASE_NOTES.md`): `git add -A`
9. Commit with message: `vX.Y.Z: <user's description>`
10. Push: `git push -u origin HEAD`
11. Create a PR via `gh pr create` using a HEREDOC body in this format:
    - Title: `vX.Y.Z: <user's description>`
    - Body:
    ```
    ## What changed
    <1-3 sentences explaining what was added, removed, or modified and why. Written for someone who uses the skill, not someone reading the code.>

    ## How to use it
    <Show the new/changed commands or config options with example invocations. Skip this section if the change is purely internal (e.g., bug fix, performance improvement) with no user-facing difference.>

    ## Release notes (vX.Y.Z)
    <Paste the bullet points from the RELEASE_NOTES.md entry you just wrote.>
    ```
12. Switch back to `main`: `git checkout main`
13. Display the PR URL.

### `cancel <id>`
Close the PR and mark the todo as cancelled.

1. If the todo has a PR URL and status is `pr open`, close the PR via `gh pr close <pr-url>`.
2. If the todo has a branch, delete the remote branch via `git push origin --delete <branch>`.
3. If the todo has a `worktreePath`, remove the git worktree via `git -C <repoPath> worktree remove <worktreePath> --force`.
4. Set status to `cancelled`. Clear `worktreePath`. Update timestamp.
5. Display updated table.

### `chat <id> <message>`
Interactive Q&A about a todo item. Load full context, then answer the user's question conversationally.

1. Read the todo from JSON.
2. Load all available context in parallel: the plan file, the result file if it exists, the review file if it exists, and the todo's notes.
3. Answer the user's `<message>` using that context. You have full access to the repo at `repoPath` — if the question requires reading code, exploring files, or checking git history to give a good answer, do so.
4. Keep the conversation natural. The user may ask follow-ups as normal messages — continue answering in context of this todo item until they move on.
5. **After each exchange, append a concise summary to `notes[]`** with a `[chat]` prefix so future sessions have context. Format: `[chat] Q: <user's question> → A: <1-2 sentence summary of your answer>`. Only capture the key takeaway, not the full response. If the chat led to a decision or action item, note that specifically.

### `review <id> [--dry-run] [overrides]`
Auto-address PR review comments from AI reviewers or human reviewers.

1. Require status `pr open`. If not, tell user.
2. Fetch all review comments via `gh api repos/{owner}/{repo}/pulls/{number}/comments` and reviews via `gh pr view <pr-url> --json reviews`. Number each comment sequentially (1, 2, 3...) for override references.
3. If `--dry-run`, present a numbered table of comments with a verdict for each:
   - **fix** — valid issue, will address
   - **dismiss** — noise, style nit, or incorrect suggestion (explain why)
   - **ask** — ambiguous, needs human input
   Show the table and stop. User can re-run with overrides to change verdicts.
4. If not `--dry-run`:
   - **Parse overrides** if present. Overrides are inline after the id, format: `fix:1,3 dismiss:2,5` (comma-separated comment numbers per verdict). Any comment not mentioned in overrides keeps its auto-assigned verdict.
   - Read the reviewer prompt template from `${CLAUDE_SKILL_DIR}/reviewer-prompt.md`, fill in the context (including final verdicts after overrides), and spawn a background agent with `run_in_background: true` and `isolation: "worktree"` to address the fixable comments.
5. Clear `needsReview` flag on the todo. Update timestamp.

**Example flow:**
```
/minion review 7 --dry-run          → shows numbered table with auto verdicts
/minion review 7 fix:2 dismiss:3   → runs with comment #2 forced to fix, #3 to dismiss
/minion review 7                    → runs with all auto verdicts (no overrides)
```

### `plan <id>`
Reset status to `planning...`. Spawn background planner. This also works for todos stuck in `planning...` (re-runs the planner).

### `execute <id> <branch> [base]`
1. Require status `plan ready`. If not, tell user to plan first.
2. Require branch name. Ask if missing.
3. Optional third arg is the base branch (e.g., `release/1.5.0`). If not provided, the agent auto-detects: checks for the latest `release/*` branch in the repo, falls back to `main`.
4. Set status `in progress`, save `branch` and `baseBranch`. Write JSON.
5. Read plan from `$HOME_DIR/.claude/todo-plans/plan-{id}.md`.
6. Read executor prompt template from `${CLAUDE_SKILL_DIR}/executor-prompt.md`.
7. Replace `{todo description}`, `{todo notes}`, `{repoPath}`, `{branch}`, `{baseBranch}`, `{id}`, `{homedir}`, `{squashCommits}`, and `{plan contents}` in the template.
8. Spawn Agent with `run_in_background: true` and `isolation: "worktree"` using the filled prompt.
9. Tell user: "Execution started for todo #{id} on branch `{branch}` (base: `{baseBranch || auto-detect}`). Use `/minion status {id}` to check progress."

## Agents

### Planner (used by `add` and `plan`)
1. Read template from `${CLAUDE_SKILL_DIR}/planner-prompt.md`.
2. Replace `{todo description}`, `{todo notes}`, `{repoPath}`, `{id}`, `{description}`, `{repo}`, `{homedir}` in the template.
3. Spawn Agent with `run_in_background: true` using the filled prompt.
4. Tell user: "Background planner started for todo #{id}. Use `/minion list` or `/minion status {id}` to check when ready."

## Auto-execute

**CRITICAL:** When a plan's verdict is `auto-execute` and it is discovered during any reconciliation (`list`, `status`, `watch`, or background agent notification), you MUST immediately begin execution. **NEVER** ask the user for confirmation, input, or whether they want to proceed. **NEVER** present options like "Want me to execute it?" or "Should I hold?". **NEVER** mention other todos, PRs, or dependencies as a reason to pause — the `auto-execute` verdict already means the planner determined this is safe to run. Just execute it silently and report that it started.

Steps (execute all of these without any user interaction):

1. **Generate semantic branch name:** `$GIT_USER/<2-4 keyword slug from description>` (e.g., `aalok/sticky-page-tabs`, `aalok/offline-persistent-footer`). Extract the most descriptive keywords from the todo description, kebab-case them, and keep it concise. Sanitize `$GIT_USER` for branch names (lowercase, replace spaces with `-`).
2. **Auto-detect base branch:** check for the latest `release/*` branch in the repo, fall back to `main`.
3. **Set status** to `in progress`, save `branch` and `baseBranch`. Write JSON.
4. **Read plan** from `$HOME_DIR/.claude/todo-plans/plan-{id}.md`.
5. **Read executor prompt** from `${CLAUDE_SKILL_DIR}/executor-prompt.md`, fill template.
6. **Spawn executor agent** with `run_in_background: true` and `isolation: "worktree"`.
7. **Tell user:** "Auto-executing todo #{id} on branch `{branch}` (base: `{baseBranch}`). Use `/minion status {id}` to check progress."

This is the same flow as `execute`, but the branch name is auto-generated and the user is never asked to provide one. The only output the user should see is the notification that execution has started — no questions, no options, no confirmations.
