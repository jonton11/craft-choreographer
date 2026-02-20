# Workflow state and phase transitions

Craft Choreographer uses a single state file (`.craft/state.json`) and a phase-based state machine. The workflow script and orchestrator read/write this state; the script does not run the LLM.

## Phases

| Phase | Description |
|-------|-------------|
| `idle` | No active workflow. Waiting for user to send `/craft <goal>`. |
| `investigating` | Investigator is running or should run. Input: `initial_prompt`. |
| `planning` | Planner is running or should run. Input: `investigation_output`. |
| `awaiting_approval` | Plan is ready. Human must reply "approve" or provide edits. No spawns until approved. |
| `executing` | Running pieces in order: Writer → Chore → Test runner (and optionally Reviewer, Context helper) per piece. |
| `done` | All pieces complete, PRs pass CI. Optional: reset to `idle` for a new `/craft`. |

## State schema

The state file is JSON with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `phase` | string | One of: `idle`, `investigating`, `planning`, `awaiting_approval`, `executing`, `done`. |
| `initial_prompt` | string | The user's loose goal (from `/craft <goal>`). |
| `investigation_output` | string | Output from the Investigator agent. |
| `plan_output` | string or object | Output from the Planner (e.g. YAML or JSON with pieces, order, acceptance criteria). |
| `refined_goal` | string | One-sentence goal from the Planner; execution agents use this as the single source of truth for what we're building. |
| `approved` | boolean | True after the user approves the plan. |
| `piece_index` | number | Current piece being executed (0-based). |
| `pieces` | array | List of pieces from the plan. Each item may have `id`, `title`, `acceptance_criteria`, `order`. |
| `executing_substep` | string | When `phase` is `executing`: `writer` \| `chore` \| `test_run`. Determines which agent prompt to run next. |
| `last_step_output` | string | Output from the last completed step (e.g. Writer or Chore) for chaining. |
| `scope_creep_detected` | boolean | If true, workflow requires human approval before continuing. |
| `updated_at` | string | ISO 8601 timestamp of last state update (optional). |

## Transitions

1. **idle** → **investigating**: User sends `/craft` or `/craft <goal>`. Script sets `initial_prompt`, `phase: "investigating"`.
2. **investigating** → **planning**: After Investigator output is written to `investigation_output`, set `phase: "planning"`. (Orchestrator or model does the write; script may advance phase on next hook run, or the orchestrator instructs the model to update state and phase.)
3. **planning** → **awaiting_approval**: After Planner output is written to `plan_output` and `refined_goal` is set (from the plan), set `phase: "awaiting_approval"`.
4. **awaiting_approval** → **executing**: User replies "approve" (or equivalent). Script sets `approved: true`, `phase: "executing"`, `piece_index: 0`.
5. **awaiting_approval** (user edits plan): Re-run Planner with edit or update `plan_output`; remain in `awaiting_approval` until user approves.
6. **executing**: For each piece in order, run Writer (until acceptance criteria met) → Chore → Test runner → optional Context helper. After each piece, increment `piece_index`. If scope creep detected, set `scope_creep_detected: true` and transition to **awaiting_approval** (re-gate).
7. **executing** → **done**: When `piece_index` >= length of `pieces` and PRs pass CI (and no scope creep), set `phase: "done"`.
8. **done** → **idle**: Optional: reset state for a new `/craft` (e.g. clear outputs, set `phase: "idle"`).

## Where state is used

- **Workflow script**: Reads state to decide phase; writes state when `/craft` is detected or when user says "approve". For Claude Code, script also uses state to fill the current phase's prompt template and return `additionalContext`.
- **Cursor orchestrator** (`.cursor/commands/craft.md`): Instructs the model to read `.craft/state.json`, run the appropriate agent prompt for the current phase, and write outputs back to state (and advance phase) as needed.
- **Agent prompts**: Receive placeholders filled from state (e.g. `{{initial_prompt}}`, `{{refined_goal}}`, `{{investigation_output}}`, `{{plan_output}}`, `{{current_piece}}`). Execution agents prefer `refined_goal` for scope; the workflow script falls back to `initial_prompt` if `refined_goal` is missing.
