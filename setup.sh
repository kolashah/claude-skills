#!/bin/bash
# Setup script for the /minion Claude Code skill
# Run: bash ~/.claude/skills/minion/setup.sh

set -e

HOME_DIR="$HOME"
CLAUDE_DIR="$HOME_DIR/.claude"
CONFIG_FILE="$CLAUDE_DIR/todo-config.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
TODOS_FILE="$CLAUDE_DIR/todos.json"
PLANS_DIR="$CLAUDE_DIR/todo-plans"

echo "=== /minion skill setup ==="
echo ""

# 1. Create todo-plans directory
mkdir -p "$PLANS_DIR"
echo "✓ Created $PLANS_DIR"

# 2. Initialize todos.json if missing
if [ ! -f "$TODOS_FILE" ]; then
  echo '{"nextId": 1, "todos": []}' > "$TODOS_FILE"
  echo "✓ Created $TODOS_FILE"
else
  echo "✓ $TODOS_FILE already exists"
fi

# 3. Create or update todo-config.json
if [ -f "$CONFIG_FILE" ]; then
  echo ""
  echo "Existing config found at $CONFIG_FILE:"
  cat "$CONFIG_FILE"
  echo ""
  read -p "Overwrite? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Keeping existing config."
    SKIP_CONFIG=true
  fi
fi

if [ "${SKIP_CONFIG}" != "true" ]; then
  echo ""
  echo "Configure your repo shorthands."
  echo "Enter shorthand and absolute path pairs (empty shorthand to finish):"
  echo "  Example: crm /Users/jane/projects/elise-crm-mobile"
  echo ""

  REPOS="{"
  FIRST=true
  while true; do
    read -p "  Shorthand: " shorthand
    [ -z "$shorthand" ] && break
    read -p "  Path: " repo_path

    if [ ! -d "$repo_path" ]; then
      echo "  ⚠ Directory '$repo_path' does not exist. Adding anyway."
    fi

    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      REPOS="$REPOS,"
    fi
    REPOS="$REPOS
    \"$shorthand\": \"$repo_path\""
  done
  REPOS="$REPOS
  }"

  cat > "$CONFIG_FILE" << CONFIGEOF
{
  "repos": $REPOS
}
CONFIGEOF

  echo ""
  echo "✓ Wrote $CONFIG_FILE"
fi

# 4. Add permissions to settings.json
echo ""
echo "Adding /minion permissions to $SETTINGS_FILE..."

# Resolve the skill directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

TODO_PERMISSIONS=(
  "Read($HOME_DIR/.claude/todos.json)"
  "Write($HOME_DIR/.claude/todos.json)"
  "Edit($HOME_DIR/.claude/todos.json)"
  "Read($HOME_DIR/.claude/todo-plans/*)"
  "Write($HOME_DIR/.claude/todo-plans/*)"
  "Edit($HOME_DIR/.claude/todo-plans/*)"
  "Read($HOME_DIR/.claude/todo-config.json)"
  "Edit($HOME_DIR/.claude/todo-config.json)"
  "Read($HOME_DIR/.claude/todo-last-seen-version)"
  "Write($HOME_DIR/.claude/todo-last-seen-version)"
  "Read($SCRIPT_DIR/*)"
)

if [ ! -f "$SETTINGS_FILE" ]; then
  # Create settings.json from scratch
  PERMS_JSON=""
  for p in "${TODO_PERMISSIONS[@]}"; do
    [ -n "$PERMS_JSON" ] && PERMS_JSON="$PERMS_JSON,"
    PERMS_JSON="$PERMS_JSON
      \"$p\""
  done

  cat > "$SETTINGS_FILE" << SETTINGSEOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [$PERMS_JSON
    ]
  }
}
SETTINGSEOF
  echo "✓ Created $SETTINGS_FILE with /minion permissions"
else
  # Check which permissions are missing and add them
  ADDED=0
  for p in "${TODO_PERMISSIONS[@]}"; do
    if ! grep -qF "$p" "$SETTINGS_FILE"; then
      # Use python to safely add to the allow array (available on macOS and Linux)
      python3 -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)
perms = data.setdefault('permissions', {}).setdefault('allow', [])
entry = '$p'
if entry not in perms:
    perms.append(entry)
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null && ADDED=$((ADDED + 1))
    fi
  done

  if [ $ADDED -gt 0 ]; then
    echo "✓ Added $ADDED permission(s) to $SETTINGS_FILE"
  else
    echo "✓ All /minion permissions already present"
  fi
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Usage:"
echo "  /minion add <repo-shorthand> <description>"
echo "  /minion list"
echo "  /minion help"
echo ""
echo "To add more repos later, edit $CONFIG_FILE"
