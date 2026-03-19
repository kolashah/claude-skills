# /minion — Claude Code Task Automation Skill

A [Claude Code](https://claude.com/claude-code) skill that manages a cross-repo todo list with autonomous background agents for planning, executing, and reviewing code changes.

## What it does

`/minion` turns a one-line task description into a planned, implemented, and PR'd code change — without leaving your terminal.

```
/minion add crm make page tabs sticky
```

This will:
1. Scope the task and ask clarifying questions if needed
2. Spawn a **background planner agent** that explores the repo, reads conventions, checks recent commits, and writes a detailed implementation plan
3. When ready, you review the plan and either execute it or adjust
4. The **executor agent** implements the plan in an isolated git worktree, runs formatters/linters/tests, commits, pushes, and opens a PR
5. When reviewers leave comments, the **reviewer agent** triages them, fixes valid issues, dismisses noise, and force-pushes

You stay in control at every step. The agents do the grunt work.

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
git clone git@github.com:MeetElise/claude-skills.git ~/.claude/skills/minion

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

- **not started** → task just added, planner about to start
- **planning...** → background planner agent is exploring the repo
- **plan ready** → plan written, waiting for you to review/execute
- **in progress** → executor agent is implementing in a worktree
- **pr open** → PR created, waiting for review/merge
- **complete** → PR merged (auto-detected)
- **cancelled** → PR closed, branch deleted

## Usage examples

### Basic flow

```bash
# Add a task — planner starts automatically in background
/minion add crm make the settings page tabs sticky

# Check status after a minute or two
/minion list

# Review the plan
/minion status 3

# Execute it (creates branch, implements, opens PR)
/minion execute 3 aalok/sticky-tabs

# After reviewers comment, auto-address their feedback
/minion review 3 --dry-run        # preview what it'll do
/minion review 3                   # fix valid issues, dismiss noise
```

### With Slack context

```bash
# Pull context from a Slack thread
/minion add crm block outbound calls --slack https://slack.com/archives/C0X.../p1234

# Or search Slack for relevant messages
/minion add api fix auth redirect --slack "auth redirect broken after deploy"
```

### Batch execution

```bash
# Execute multiple planned tasks in parallel
/minion batch execute 3,4,5 release/1.5.0
```

### Monitoring

```bash
# Watch a task — get notified when plan is ready, PR is created, etc.
/minion watch 3

# Or poll manually
/loop 5m /minion list
```

### Chat about a task

```bash
# Ask questions about the plan or codebase
/minion chat 3 what tradeoffs did you consider for the state management?

# Follow up naturally
/minion chat 3 would it be better to use a StreamBuilder here?
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
