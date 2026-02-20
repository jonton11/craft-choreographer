#!/usr/bin/env bash
# Initialize a project to use Craft Choreographer from an existing install.
# Run this from the craft-choreographer repo, or pass the repo path as second argument.
#
# Usage:
#   /path/to/craft-choreographer/scripts/init-project.sh [TARGET_PROJECT_DIR]
#
# Example: from your app repo:
#   ~/craft-choreographer/scripts/init-project.sh .
#
# Example: from craft-choreographer repo:
#   ./scripts/init-project.sh /path/to/my-app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRAFT_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-.}"

if [[ ! -f "$CRAFT_HOME/.craft/workflow.sh" ]]; then
  echo "Error: Craft Choreographer not found at $CRAFT_HOME (.craft/workflow.sh missing)." >&2
  exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
echo "Initializing Craft Choreographer in project: $TARGET_DIR"
echo "Using Craft install: $CRAFT_HOME"

# Create .craft in project
mkdir -p "$TARGET_DIR/.craft"

# Write config with absolute path so hooks work regardless of cwd
echo "$CRAFT_HOME" > "$TARGET_DIR/.craft/config"

# Wrapper script: reads CRAFT_HOME from config, exec's real workflow (same stdin)
cat > "$TARGET_DIR/.craft/workflow.sh" << 'WRAPPER_EOF'
#!/usr/bin/env bash
set -e
CRAFT_DIR="$(dirname "$0")"
CONFIG="$CRAFT_DIR/config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Craft not configured. Run init-project.sh from the craft-choreographer repo." >&2
  exit 1
fi
CRAFT_HOME="$(cat "$CONFIG")"
if [[ ! -x "$CRAFT_HOME/.craft/workflow.sh" ]]; then
  echo "Craft install not found at $CRAFT_HOME. Edit .craft/config to fix." >&2
  exit 1
fi
exec "$CRAFT_HOME/.craft/workflow.sh"
WRAPPER_EOF
chmod +x "$TARGET_DIR/.craft/workflow.sh"

# Symlink prompts so both the hook and the orchestrator see them (and updates propagate)
if [[ -d "$TARGET_DIR/.craft/prompts" ]] && [[ ! -L "$TARGET_DIR/.craft/prompts" ]]; then
  echo "Note: $TARGET_DIR/.craft/prompts already exists (not a symlink). Leaving it as-is." >&2
else
  rm -rf "$TARGET_DIR/.craft/prompts" 2>/dev/null || true
  ln -s "$CRAFT_HOME/.craft/prompts" "$TARGET_DIR/.craft/prompts"
fi

# Cursor: hooks and command
mkdir -p "$TARGET_DIR/.cursor/commands"
cp "$CRAFT_HOME/.cursor/hooks.json" "$TARGET_DIR/.cursor/hooks.json"
cp "$CRAFT_HOME/.cursor/commands/craft.md" "$TARGET_DIR/.cursor/commands/craft.md"

# Claude Code: settings (merge or create)
CLAUDE_DIR="$TARGET_DIR/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
mkdir -p "$CLAUDE_DIR"
if [[ -f "$CLAUDE_SETTINGS" ]]; then
  echo "Note: $CLAUDE_SETTINGS exists. Ensure it has a UserPromptSubmit hook that runs ./.craft/workflow.sh" >&2
  echo "  See $CRAFT_HOME/.claude/settings.json for reference." >&2
else
  cp "$CRAFT_HOME/.claude/settings.json" "$CLAUDE_SETTINGS"
fi

# Ensure state.json is gitignored in the project
GITIGNORE="$TARGET_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q '\.craft/state\.json' "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Craft Choreographer state (do not commit)" >> "$GITIGNORE"
    echo ".craft/state.json" >> "$GITIGNORE"
  fi
else
  echo ".craft/state.json" > "$GITIGNORE"
fi

echo "Done. You can use /craft in this project (Cursor or Claude Code)."
echo "State will be stored in $TARGET_DIR/.craft/state.json (gitignored)."
