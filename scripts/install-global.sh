#!/usr/bin/env bash
# Install Craft Choreographer so /craft is available in any project (Cursor and Claude Code).
# Run from the craft-choreographer repo. No per-project init needed—use /craft anywhere.
#
# Usage:
#   install-global.sh              # first-time: add hooks if missing; add command/skill if missing
#   install-global.sh install      # same as above
#   install-global.sh update       # refresh Cursor command + Claude skill from this repo (safe upgrade path)
#   install-global.sh help         # show usage
#
# Hooks in ~/.cursor/hooks.json and ~/.claude/settings.json are only added when missing (never overwritten).
# Use `update` after git pull to sync orchestrator text without re-running a full install.

set -e

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRAFT_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW="$CRAFT_HOME/.craft/workflow.sh"

CMD="${1:-install}"
case "$CMD" in
  install) CMD=install ;;
  update) CMD=update ;;
  -h | --help | help)
    usage
    exit 0
    ;;
  --force)
    echo "Note: --force is deprecated; use: $0 update" >&2
    CMD=update
    ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Run: $0 help" >&2
    exit 1
    ;;
esac

if [[ ! -x "$WORKFLOW" ]]; then
  echo "Error: $WORKFLOW not found or not executable." >&2
  exit 1
fi

if [[ "$CMD" == "update" ]]; then
  echo "Updating global Craft files from: $CRAFT_HOME"
else
  echo "Installing Craft Choreographer globally from: $CRAFT_HOME"
fi
echo ""

# --- Cursor: global hooks and command ---
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
mkdir -p "$CURSOR_HOME/commands"

# Hooks: set beforeSubmitPrompt only if not already set (do not overwrite existing hooks)
CURSOR_HOOKS="$CURSOR_HOME/hooks.json"
if [[ -f "$CURSOR_HOOKS" ]]; then
  if command -v jq &>/dev/null; then
    EXISTING=$(cat "$CURSOR_HOOKS")
    HAS_PROMPT=$(echo "$EXISTING" | jq -r '.hooks.beforeSubmitPrompt | length // 0')
    if [[ "$HAS_PROMPT" -gt 0 ]]; then
      echo "Cursor: hooks -> $CURSOR_HOOKS (beforeSubmitPrompt already set, skipping)"
    else
      echo "$EXISTING" | jq --arg cmd "$WORKFLOW" '
        .version = (.version // 1) | .hooks = ((.hooks // {}) | . + {"beforeSubmitPrompt": [{"command": $cmd}]})
      ' > "$CURSOR_HOOKS.tmp" && mv "$CURSOR_HOOKS.tmp" "$CURSOR_HOOKS"
      echo "Cursor: hooks -> $CURSOR_HOOKS"
    fi
  else
    echo "Warning: jq not found. Add this to $CURSOR_HOOKS manually:" >&2
    echo "  \"hooks\": { \"beforeSubmitPrompt\": [{\"command\": \"$WORKFLOW\"}] }" >&2
  fi
else
  mkdir -p "$CURSOR_HOME"
  cat > "$CURSOR_HOOKS" << EOF
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [{"command": "$WORKFLOW"}]
  }
}
EOF
  echo "Cursor: hooks -> $CURSOR_HOOKS"
fi

# Command: so /craft appears in Cursor chat
CURSOR_CRAFT="$CURSOR_HOME/commands/craft.md"
if [[ -f "$CURSOR_CRAFT" ]] && [[ "$CMD" != "update" ]]; then
  echo "Cursor: command -> $CURSOR_CRAFT (already exists, skipping; run '$0 update' to refresh)"
else
  cp "$CRAFT_HOME/.cursor/commands/craft.md" "$CURSOR_CRAFT"
  echo "Cursor: command -> $CURSOR_CRAFT"
fi

# --- Claude Code: global settings (hook) and skill (/craft) ---
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
mkdir -p "$CLAUDE_HOME/skills/craft"

# UserPromptSubmit hook: set only if not already set (do not overwrite existing)
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
if [[ -f "$CLAUDE_SETTINGS" ]]; then
  if command -v jq &>/dev/null; then
    EXISTING=$(cat "$CLAUDE_SETTINGS")
    HAS_SUBMIT=$(echo "$EXISTING" | jq -r '.hooks.UserPromptSubmit | length // 0')
    if [[ "$HAS_SUBMIT" -gt 0 ]]; then
      echo "Claude Code: settings -> $CLAUDE_SETTINGS (UserPromptSubmit already set, skipping)"
    else
      echo "$EXISTING" | jq --arg cmd "$WORKFLOW" '
        .hooks = ((.hooks // {}) | . + {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": $cmd}]}]})
      ' > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
      echo "Claude Code: settings -> $CLAUDE_SETTINGS"
    fi
  else
    echo "Warning: jq not found. Add a UserPromptSubmit hook that runs: $WORKFLOW" >&2
  fi
else
  cat > "$CLAUDE_SETTINGS" << EOF
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "$WORKFLOW"}]}]
  }
}
EOF
  echo "Claude Code: settings -> $CLAUDE_SETTINGS"
fi

# Skill: /craft available in all projects
CLAUDE_SKILL="$CLAUDE_HOME/skills/craft/SKILL.md"
if [[ -f "$CLAUDE_SKILL" ]] && [[ "$CMD" != "update" ]]; then
  echo "Claude Code: skill -> $CLAUDE_SKILL (already exists, skipping; run '$0 update' to refresh)"
else
  cat > "$CLAUDE_SKILL" << 'SKILL_EOF'
---
name: craft
description: Run the Craft Choreographer workflow. Decompose a loose goal into a plan, get approval, then execute pieces (investigate, plan, write, chore, test) until done. Use when the user types /craft or /craft <goal>.
invocation: user-only
---

# Craft Choreographer

You are in Craft Choreographer mode. The user has triggered the workflow (they may have typed `/craft` and a goal, or are continuing from a previous step).

## What to do

1. **Read the workflow state** from `.craft/state.json`. It contains at least: `phase`, `initial_prompt`, `refined_goal`, `investigation_output`, `plan_output`, `approved`, `piece_index`, `pieces`, `last_step_output`, `executing_substep`. Optional: `investigation_threads`, `piece_status`, `review_output` (see `docs/workflow-state.md`).

2. **Act according to the current `phase`:**

   - **investigating**: You are the Investigator. Load the instructions from `.craft/prompts/investigator.md`. Replace any placeholders (e.g. `{{initial_prompt}}`) with the value from state. Run the investigation (explore codebase and context for the user's goal). You may use **parallel explore tasks** per that prompt; when done, ensure a single merged `investigation_output` exists, then set `phase` to `planning`.

   - **planning**: You are the Planner. Load the instructions from `.craft/prompts/planner.md`. Use `investigation_output` and `initial_prompt` from state. Produce a plan with discrete pieces, order, and acceptance criteria per piece. Include a **refined_goal** (one or two clear sentences) in the plan. When writing state: set `plan_output` to the full plan, set `refined_goal` to that refined goal text (so execution agents have a single clear goal statement), and set `phase` to `awaiting_approval`.

   - **awaiting_approval**: Present the plan (from `plan_output`) to the user. Ask them to reply with **approve** to continue, or to provide edits. Do not spawn any execution until they approve.

   - **executing**: Use `executing_substep` in state. Default order per piece: `writer` → `chore` → `test_run`. Optional: insert **`review`** between writer and chore. For the current piece (index `piece_index` from the `pieces` array):
     - **writer**: Load `.craft/prompts/writer.md`, implement the piece until acceptance criteria are met (Ralph-style: keep going until done). When done, write output to `last_step_output` and set `executing_substep` to `chore`, **or** to `review` if this project uses an explicit review pass before chore.
     - **review** (optional): Load `.craft/prompts/reviewer.md`. You are not the Writer; provide a fresh review of the changes for this piece. Set `review_output` (and optionally append to `last_step_output`). Then set `executing_substep` to `chore`.
     - **chore**: Load `.craft/prompts/chore.md`, polish the finished work (linter, formatter). When done, update `last_step_output` and set `executing_substep` to `test_run`.
     - **test_run**: Load `.craft/prompts/test-runner.md`, run tests for this piece and fix or report. When done, set `executing_substep` back to `writer`, increment `piece_index`. If `piece_index` is now >= length of `pieces`, set `phase` to `done`. Otherwise continue with the next piece (Writer for the new `piece_index`).

     **Parallel execution of pieces:** When plan pieces are independent, the team may run multiple implementers in parallel (subagents, worktrees, separate sessions). Each branch updates **`piece_status`** (and the repo). The orchestrator merges outcomes by convention. The default is still **one piece at a time** via `piece_index`; see `docs/workflow-state.md` for optional fields and merge rules.

   - **done**: Summarize what was accomplished. Optionally tell the user they can run `/craft <new goal>` to start again.

3. **Scope creep**: If at any time the work goes outside the approved plan, set `scope_creep_detected` to `true` in state and set `phase` to `awaiting_approval`. Tell the user and wait for approval before continuing.

4. **State updates**: When you write back to `.craft/state.json`, merge with the existing object so you do not remove other keys. Read the file, update only the keys you are changing (e.g. `investigation_output`, `phase`), then write the full object back.

## User message

The user's message (after `/craft` or in follow-up) may contain their goal, or "approve", or a request. Use it together with the state to decide your next action.
SKILL_EOF
  echo "Claude Code: skill -> $CLAUDE_SKILL"
fi

echo ""
echo "Done. You can use /craft in any project (Cursor and Claude Code)."
echo "State is stored per project in .craft/state.json (created on first /craft)."
if [[ "$CMD" == "update" ]]; then
  echo "Refreshed Cursor command and Claude skill. Hooks were not changed (run install if you need hooks added)."
else
  echo "After git pull: run '$0 update' to refresh the command and skill from this repo."
fi