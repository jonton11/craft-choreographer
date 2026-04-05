# Workflow state and phase transitions

Craft Choreographer uses a single state file (`.craft/state.json`) and a phase-based state machine. The workflow script and orchestrator read/write this state; the script does not run the LLM.

## Phases

| Phase | Description |
|-------|-------------|
| `idle` | No active workflow. Waiting for user to send `/craft <goal>`. |
| `investigating` | Investigator is running or should run. Input: `initial_prompt`. |
| `planning` | Planner is running or should run. Input: `investigation_output`. |
| `awaiting_approval` | Plan is ready. Human must send **`/craft:approve`** to accept (hook updates state) or provide edits. No spawns until approved. |
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
| `approved` | boolean | True after the user sends **`/craft:approve`** (workflow hook sets this with `phase: executing`). |
| `piece_index` | number | Current piece being executed (0-based). |
| `pieces` | array | List of pieces from the plan. Each item may have `id`, `title`, `acceptance_criteria`, `order`. |
| `executing_substep` | string | When `phase` is `executing`: `writer` \| optional `review` \| `chore` \| `test_run`. Default path skips `review` (Writer → Chore → Test runner). |
| `last_step_output` | string | Output from the last completed step (e.g. Writer or Chore) for chaining. |
| `review_output` | string | Optional. Structured review from `.craft/prompts/reviewer.md` when `executing_substep` is `review`. |
| `scope_creep_detected` | boolean | If true, workflow requires human approval before continuing. |
| `updated_at` | string | ISO 8601 timestamp of last state update (optional). |

### Optional fields for parallel agents and fan-out

These fields are **optional**. The default workflow uses a single model, one `investigation_output`, and serial `piece_index`. Use the extras when your editor or process runs **multiple agents or branches** that must **write back into the same flow** via `.craft/state.json`.

| Field | Type | When to use |
|-------|------|-------------|
| `investigation_threads` | array of objects | Parallel or spawned investigators each produce one element (e.g. `{ "area": "api", "summary": "..." }`) before planning. |
| `investigation_merge_version` | number or string | Optional marker so you know which merge generation `investigation_output` reflects. |
| `piece_status` | array of objects | Parallel execution: one entry per plan piece, e.g. `{ "id": 1, "status": "in_progress" \| "done" \| "blocked", "notes": "..." }`. The orchestrator advances `piece_index` or marks pieces done according to your team convention. |

**Merge rules (investigation):** After parallel exploration, produce **one** `investigation_output` the Planner already expects: (1) append each thread’s summary under a clear heading (e.g. `## API`, `## UI`); (2) deduplicate overlapping facts; (3) add a short `## Conflicts / open questions` section if threads disagree; (4) clear `investigation_threads` or leave them as audit trail—Planner should read `investigation_output` as canonical unless you explicitly teach it otherwise.

**Merge rules (execution):** When pieces run in parallel (separate sessions, subagents, or worktrees), each branch updates **`piece_status`** (and file changes in the repo). When a piece is finished, set its status to `done` and record PR link or commit in `notes` if useful. The main orchestrator either picks the next incomplete piece (serial) or waits until all pieces in a wave are `done` before moving on. Conflicting edits to the same files should be resolved before marking `done`.

**Optional review substep:** After Writer, set `executing_substep` to `review` to run `.craft/prompts/reviewer.md`, then continue to `chore`. Store review text in `review_output` and/or append to `last_step_output` as your team prefers.

## Transitions

1. **idle** → **investigating**: User sends `/craft` or `/craft <goal>`. Script sets `initial_prompt`, `phase: "investigating"`.
2. **investigating** → **planning**: After Investigator output is written to `investigation_output`, set `phase: "planning"`. (Orchestrator or model does the write; script may advance phase on next hook run, or the orchestrator instructs the model to update state and phase.)
3. **planning** → **awaiting_approval**: After Planner output is written to `plan_output` and `refined_goal` is set (from the plan), set `phase: "awaiting_approval"`.
4. **awaiting_approval** → **executing**: User sends exactly **`/craft:approve`**. Script sets `approved: true`, `phase: "executing"`, `piece_index: 0`. (Natural-language “approve” does **not** trigger the hook; orchestrator must not advance execution until state reflects this transition.)
5. **awaiting_approval** (user edits plan): Re-run Planner with edit or update `plan_output`; remain in `awaiting_approval` until user sends **`/craft:approve`**.
6. **executing**: For each piece in order, run Writer (until acceptance criteria met) → optional Review → Chore → Test runner → optional Context helper. After each piece, increment `piece_index`. If scope creep detected, set `scope_creep_detected: true` and transition to **awaiting_approval** (re-gate until **`/craft:approve`**). Parallel piece execution is supported via `piece_status` and team conventions, not by `workflow.sh` alone.
7. **executing** → **done**: When `piece_index` >= length of `pieces` and PRs pass CI (and no scope creep), set `phase: "done"`.
8. **done** → **idle**: Optional: reset state for a new `/craft` (e.g. clear outputs, set `phase: "idle"`).

## Where state is used

- **Workflow script**: Reads state to decide phase; writes state when `/craft` or `/craft <goal>` starts a run, or when the user sends **`/craft:approve`** while `phase` is `awaiting_approval`. For Claude Code, script also uses state to fill the current phase's prompt template and return `additionalContext`.
- **Cursor orchestrator** (`.cursor/commands/craft.md`): Instructs the model to read `.craft/state.json`, run the appropriate agent prompt for the current phase, and write outputs back to state (and advance phase) as needed. When `phase` is **`awaiting_approval`**, if the user’s message sounds like approval but is not exactly **`/craft:approve`**, the orchestrator should **clarify** and **redirect** to **`/craft:approve`**—natural language alone does not run the hook; the agent must not advance to **`executing`** until state reflects the hook transition.
- **Agent prompts**: Receive placeholders filled from state (e.g. `{{initial_prompt}}`, `{{refined_goal}}`, `{{investigation_output}}`, `{{plan_output}}`, `{{current_piece}}`). Execution agents prefer `refined_goal` for scope; the workflow script falls back to `initial_prompt` if `refined_goal` is missing.
