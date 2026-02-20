#!/usr/bin/env bash
# Craft Choreographer workflow script.
# Invoked by Cursor (beforeSubmitPrompt) or Claude Code (UserPromptSubmit).
# Reads JSON from stdin; writes state to .craft/state.json; for Claude, may output JSON with additionalContext.

set -e

CRAFT_DIR="${CRAFT_DIR:-.craft}"
PROMPTS_DIR="$CRAFT_DIR/prompts"
STATE_FILE="$CRAFT_DIR/state.json"

# Read hook input from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // .hookEventName // empty')
# Claude sends cwd; Cursor sends workspace_roots
ROOT=$(echo "$INPUT" | jq -r 'if .cwd then .cwd elif .workspace_roots then .workspace_roots[0] else "" end')
if [[ -z "$ROOT" ]]; then
  ROOT="."
fi
STATE_PATH="$ROOT/$STATE_FILE"
PROMPTS_PATH="$ROOT/$PROMPTS_DIR"

# Ensure state file exists with at least phase
ensure_state() {
  if [[ ! -f "$STATE_PATH" ]]; then
    mkdir -p "$(dirname "$STATE_PATH")"
    echo '{"phase":"idle"}' > "$STATE_PATH"
  fi
}

# Read state field
state_get() {
  local key="$1"
  jq -r --arg k "$key" '.[$k] // ""' "$STATE_PATH" 2>/dev/null || echo ""
}

# Write state (merge with existing). Usage: state_set '{"phase":"investigating"}'
state_set() {
  local tmp
  tmp=$(mktemp)
  if [[ -f "$STATE_PATH" ]]; then
    jq -s '.[0] * .[1]' "$STATE_PATH" <(printf '%s' "$1") > "$tmp" 2>/dev/null || printf '%s' "$1" > "$tmp"
  else
    printf '%s' "$1" > "$tmp"
  fi
  mv "$tmp" "$STATE_PATH"
}

# Normalize prompt for approval check
is_approval() {
  local msg
  msg=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '\n' | xargs)
  [[ "$msg" == "approve" || "$msg" == "approved" || "$msg" == "yes" ]]
}

# Fill template placeholders from state (safe for JSON string)
fill_template() {
  local template="$1"
  local initial_prompt refined_goal investigation_output plan_output current_piece last_step_output
  initial_prompt=$(jq -r '.initial_prompt // "" | gsub("\\"; "\\\\") | gsub("\n"; " ")' "$STATE_PATH" 2>/dev/null || echo "")
  refined_goal=$(jq -r '.refined_goal // .initial_prompt // "" | gsub("\\"; "\\\\") | gsub("\n"; " ")' "$STATE_PATH" 2>/dev/null || echo "")
  investigation_output=$(jq -r '.investigation_output // "" | gsub("\\"; "\\\\") | gsub("\n"; " ")' "$STATE_PATH" 2>/dev/null || echo "")
  plan_output=$(jq -r '.plan_output // "" | if type == "string" then . else (. | tostring) end | gsub("\\"; "\\\\") | gsub("\n"; " ")' "$STATE_PATH" 2>/dev/null || echo "")
  current_piece=$(jq -r '.pieces[.piece_index // 0] // {} | tostring | gsub("\\"; "\\\\") | gsub("\n"; " ")' "$STATE_PATH" 2>/dev/null || echo "")
  last_step_output=$(jq -r '.last_step_output // "" | gsub("\\"; "\\\\") | gsub("\n"; " ")' "$STATE_PATH" 2>/dev/null || echo "")

  echo "$template" | \
    sed "s|{{initial_prompt}}|${initial_prompt}|g" | \
    sed "s|{{refined_goal}}|${refined_goal}|g" | \
    sed "s|{{investigation_output}}|${investigation_output}|g" | \
    sed "s|{{plan_output}}|${plan_output}|g" | \
    sed "s|{{current_piece}}|${current_piece}|g" | \
    sed "s|{{last_step_output}}|${last_step_output}|g"
}

# Output JSON for Claude Code: additionalContext with filled prompt
claude_output_context() {
  local context="$1"
  # Escape for JSON string
  local escaped
  escaped=$(echo "$context" | jq -Rs .)
  jq -n --argjson ctx "$escaped" '
    {
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $ctx
      }
    }
  '
}

ensure_state

# Detect /craft and initialize or continue workflow
if [[ "$PROMPT" == /craft* ]]; then
  # Extract goal: rest of line after /craft
  GOAL=$(echo "$PROMPT" | sed -n 's|^/craft[[:space:]]*||p' | xargs)
  state_set "{\"phase\":\"investigating\",\"initial_prompt\":$(jq -n --arg g "$GOAL" '$g'),\"approved\":false,\"piece_index\":0,\"executing_substep\":\"writer\"}"
fi

PHASE=$(state_get "phase")

# If awaiting_approval and user said approve, advance to executing
if [[ "$PHASE" == "awaiting_approval" ]] && is_approval "$PROMPT"; then
  state_set '{"approved":true,"phase":"executing","piece_index":0,"executing_substep":"writer"}'
  PHASE="executing"
fi

# Cursor: always allow prompt to proceed; orchestrator in craft.md handles phase
if [[ "$HOOK_EVENT" == "beforeSubmitPrompt" ]]; then
  echo '{"continue":true}'
  exit 0
fi

# Claude Code: inject context for current phase when we're in an active workflow
if [[ "$HOOK_EVENT" != "UserPromptSubmit" ]]; then
  exit 0
fi

if [[ "$PHASE" == "idle" ]] && [[ "$PROMPT" != /craft* ]]; then
  exit 0
fi

# For Claude, load the prompt template for current phase and return additionalContext
case "$PHASE" in
  investigating)
    if [[ -f "$PROMPTS_PATH/investigator.md" ]]; then
      TEMPLATE=$(cat "$PROMPTS_PATH/investigator.md")
      FILLED=$(fill_template "$TEMPLATE")
      claude_output_context "$FILLED"
    fi
    ;;
  planning)
    if [[ -f "$PROMPTS_PATH/planner.md" ]]; then
      TEMPLATE=$(cat "$PROMPTS_PATH/planner.md")
      FILLED=$(fill_template "$TEMPLATE")
      claude_output_context "$FILLED"
    fi
    ;;
  awaiting_approval)
    PLAN=$(state_get "plan_output")
    claude_output_context "Present the following plan to the user and wait for them to reply 'approve' or provide edits. Plan: $PLAN"
    ;;
  executing)
    SUBSTEP=$(state_get "executing_substep")
    [[ -z "$SUBSTEP" ]] && SUBSTEP="writer"
    case "$SUBSTEP" in
      writer)
        [[ -f "$PROMPTS_PATH/writer.md" ]] && TEMPLATE=$(cat "$PROMPTS_PATH/writer.md") && FILLED=$(fill_template "$TEMPLATE") && claude_output_context "$FILLED"
        ;;
      chore)
        [[ -f "$PROMPTS_PATH/chore.md" ]] && TEMPLATE=$(cat "$PROMPTS_PATH/chore.md") && FILLED=$(fill_template "$TEMPLATE") && claude_output_context "$FILLED"
        ;;
      test_run)
        [[ -f "$PROMPTS_PATH/test-runner.md" ]] && TEMPLATE=$(cat "$PROMPTS_PATH/test-runner.md") && FILLED=$(fill_template "$TEMPLATE") && claude_output_context "$FILLED"
        ;;
      *)
        [[ -f "$PROMPTS_PATH/writer.md" ]] && TEMPLATE=$(cat "$PROMPTS_PATH/writer.md") && FILLED=$(fill_template "$TEMPLATE") && claude_output_context "$FILLED"
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
