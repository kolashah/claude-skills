# /minion — Claude Code Task Automation Skill

A [Claude Code](https://claude.com/claude-code) skill that manages a cross-repo todo list with autonomous background agents for planning, executing, and reviewing code changes.

## What it does

`/minion` turns task descriptions into planned, implemented, and PR'd code changes — without leaving your terminal. Tasks can be anything from a quick one-liner to a detailed multi-line description with pasted context.

```bash
# A quick one-liner
/minion add api add rate limiting to the /users endpoint

# A detailed, multi-line task with scoping notes
/minion add crm add a blocking privacy policy screen that users must accept
  on first install before accessing the app. Use a WebView to load
  https://eliseai.com/policy, add a checkbox + accept button. Store
  acceptance in SharedPreferences, don't reset on logout.
```

After adding, the skill:
1. Scopes the task — asks clarifying questions if anything is ambiguous, skips if the description is clear enough
2. Spawns a **background planner agent** that explores the repo, reads CLAUDE.md conventions, checks recent commits, and writes a detailed implementation plan
3. When ready, you review the plan and either execute it or adjust
4. The **executor agent** implements the plan in an isolated git worktree, runs formatters/linters/tests, commits, pushes, and opens a PR
5. When reviewers leave comments, the **reviewer agent** triages them, fixes valid issues, dismisses noise, and force-pushes

You stay in control at every step. The minions do the grunt work.

## Architecture

```
You ──── /minion ──── Planner Agent (background)
              │              ↓
              │         plan-{id}.md
              │              ↓
              ├──── Executor Agent (background, isolated worktree)
              │              ↓
              │         PR created, result-{id}.md written
              │              ↓
              └──── Reviewer Agent (background, isolated worktree)
                           ↓
                     Fixes pushed, review-{id}.md written
```

### Three-agent pipeline

| Agent | Trigger | Runs in | Output |
|-------|---------|---------|--------|
| **Planner** | `/minion add` or `/minion plan` | Background | `~/.claude/todo-plans/plan-{id}.md` with approach, files, complexity, and verdict |
| **Executor** | `/minion execute` or `/minion batch execute` | Background + isolated worktree | Implements plan, creates PR, writes `result-{id}.md` |
| **Reviewer** | `/minion review` | Background + isolated worktree | Addresses review comments, writes `review-{id}.md` |

### Verdicts

After planning, each task gets a verdict:

- **auto-execute** — Simple, low-risk, no architectural decisions. Safe to execute without review.
- **review** — Complex or risky. You should read the plan before executing.
- **needs-input** — Ambiguous requirements. The planner has questions for you.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) CLI installed
- `gh` CLI authenticated (`gh auth status`)
- Git configured (`git config user.name`)

### Setup

```bash
# Clone into your Claude Code skills directory
git clone git@github.com:kolashah/claude-skills.git ~/.claude/skills/minion

# Run the interactive setup script
bash ~/.claude/skills/minion/setup.sh
```

The setup script will:
1. Create `~/.claude/todo-plans/` directory
2. Initialize `~/.claude/todos.json`
3. Prompt you to configure **repo shorthands** (e.g., `crm` → `/Users/you/projects/my-crm-app`)
4. Add required file permissions to `~/.claude/settings.json`

### Configuration

After setup, your repo shorthands live in `~/.claude/todo-config.json`:

```json
{
  "repos": {
    "crm": "/Users/you/projects/my-crm-app",
    "api": "/Users/you/projects/my-api",
    "web": "/Users/you/projects/my-web-app"
  }
}
```

Edit this file anytime to add, remove, or rename shorthands. You can also pass absolute paths directly:

```
/minion add /Users/you/projects/some-repo fix the login bug
```

## Commands

### Core workflow

| Command | Description |
|---------|-------------|
| `/minion add <repo> <description>` | Create a task and auto-plan in background |
| `/minion list` | Show all tasks with status table |
| `/minion status <id>` | Show full details, plan, and PR link |
| `/minion execute <id> <branch> [base]` | Implement plan in a worktree, push, and open PR |
| `/minion review <id> [--dry-run]` | Auto-address PR review comments |

### Task management

| Command | Description |
|---------|-------------|
| `/minion update <id> <note>` | Add context or notes to a task |
| `/minion chat <id> <message>` | Ask questions about a task's plan, context, or codebase |
| `/minion plan <id>` | Re-run the planner (e.g., after adding notes) |
| `/minion done <id>` | Mark complete |
| `/minion cancel <id>` | Close PR, delete remote branch, mark cancelled |
| `/minion remove <id>` | Delete task and all associated files |
| `/minion clean` | Remove all completed and cancelled tasks |

### Advanced

| Command | Description |
|---------|-------------|
| `/minion batch execute <ids> [base]` | Execute multiple tasks in parallel worktrees |
| `/minion watch <id>` | Monitor a task and notify on state changes (uses `/loop`) |
| `/minion review <id> fix:1,3 dismiss:2` | Override auto-assigned review verdicts |

## Status flow

```
not started → planning... → plan ready → in progress → pr open → complete
                                                                ↳ cancelled
```

- **not started** — task just added, planner about to start
- **planning...** — background planner agent is exploring the repo
- **plan ready** — plan written, waiting for you to review/execute
- **in progress** — executor agent is implementing in a worktree
- **pr open** — PR created, waiting for review/merge
- **complete** — PR merged (auto-detected)
- **cancelled** — PR closed, branch deleted

## Usage examples

### Bug fix with context

Paste in the details so the planner has full context on what broke and how to fix it:

```bash
/minion add api fix the webhook retry logic — currently retries
  are firing immediately instead of using exponential backoff.
  The retry queue in EventProcessor.processWebhook is using a
  fixed 1s delay. Should use 1s, 2s, 4s, 8s, 16s with jitter.

/minion list                       # check when plan is ready
/minion status 5                   # review the plan
/minion execute 5 fix/webhook-retry
```

### Feature implementation with detailed spec

You know exactly what you want. Give a thorough description upfront so the planner doesn't need to ask questions:

```bash
/minion add resident add a payment method details bottom sheet that shows
  card type, last 4 digits, expiry, and a "set as default" button.
  Follow the existing AppBottomSheet pattern with a static show() method.
  Wire it to the PaymentsCubit.setDefaultMethod action.
```

### Quick refactor across files

Small, mechanical changes that touch several files but follow an obvious pattern:

```bash
/minion add web rename all instances of UserProfile to ResidentProfile
  in the dashboard module. Update imports, types, and test references.

# Plan comes back as auto-execute (low risk, mechanical)
/minion execute 12 refactor/resident-profile-rename
```

### Sprint batch — plan and execute multiple tasks

Queue up several tasks, let them all plan in background, then execute in parallel:

```bash
/minion add crm add created_at column to the leads table
/minion add crm make the filter dropdown persist selection across tabs
/minion add crm fix timezone display on appointment cards

# Wait for plans...
/minion list

# Execute all at once, each in its own worktree
/minion batch execute 7,8,9 release/2.1.0
```

### Addressing PR review feedback

AI reviewers (Devin, Cursor Bugbot) or teammates leave comments on your PR. Triage them first, then let the agent fix the real issues:

```bash
# See what the reviewers said and how minion would handle each comment
/minion review 5 --dry-run

# Override a verdict (force-fix comment #2, dismiss comment #3)
/minion review 5 fix:2 dismiss:3

# Or just let it handle everything with auto verdicts
/minion review 5
```

### Investigating before acting

Not sure how something works in the codebase? Chat about a task to understand the context before executing:

```bash
/minion chat 5 how does the current retry logic work? what happens on timeout?
/minion chat 5 would it be better to use exponential backoff here?
# Decisions are saved in the task's notes for future reference
```

### Monitoring a long-running task

Start an executor and get notified when it's done:

```bash
/minion execute 5 fix/webhook-retry
/minion watch 5    # polls every 2min, notifies on state change, auto-stops when done
```

## File structure

```
~/.claude/
├── todo-config.json          # Your repo shorthands (per-user)
├── todos.json                # Task list (per-user)
├── todo-plans/               # Plan, result, and review files
│   ├── plan-3.md
│   ├── result-3.md
│   └── review-3.md
├── settings.json             # Claude Code settings (permissions added by setup)
└── skills/
    └── minion/               # This repo
        ├── SKILL.md          # Skill definition (the brain)
        ├── planner-prompt.md # Template for planner agents
        ├── executor-prompt.md# Template for executor agents
        ├── reviewer-prompt.md# Template for reviewer agents
        ├── setup.sh          # One-time setup script
        └── README.md         # This file
```

## How it works under the hood

### Data storage

All state lives in `~/.claude/todos.json` — a flat JSON file with an auto-incrementing ID counter. No database, no server.

### Agent isolation

Executor and reviewer agents run in **git worktrees** — isolated copies of the repo that don't affect your working directory. If an agent fails, your main checkout is untouched. Worktrees are cleaned up by `/minion clean` and `/minion cancel`.

### Status reconciliation

When you run `/minion list`, the skill checks for state changes without you having to manually update anything:
- Did the planner finish? (checks if plan file exists)
- Did the executor finish? (checks if result file exists)
- Did the PR get merged? (checks GitHub API)
- Are there new review comments? (checks GitHub API, throttled to every 10 min)

### Stale detection

If a planner hasn't produced a plan after 15 minutes, the task is auto-reset to `not started`. If an executor hasn't produced a result after 30 minutes, a warning note is appended. This prevents tasks from getting stuck silently.

### Permissions

The setup script adds read/write/edit permissions for `todos.json`, `todo-plans/*`, `todo-config.json`, and the skill files to your `~/.claude/settings.json`. This enables auto-approval so the skill doesn't prompt you for every file operation.

## Updating

```bash
cd ~/.claude/skills/minion
git pull
```

No re-setup needed unless the config format changes.

## Contributing

1. Edit files in `~/.claude/skills/minion/` (it's a git repo)
2. Create a branch, push, and open a PR
3. After merge, everyone updates with `git pull`
