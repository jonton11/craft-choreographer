# Using the workflow

## How `.craft/state.json` is used

The state file is the workflow’s **memory**: it persists between steps and between runs so the framework always knows where you are and what to do next.

- **Workflow script** (`.craft/workflow.sh`): On each hook run it **reads** state for `phase`, `initial_prompt`, `refined_goal`, `investigation_output`, `plan_output`, `piece_index`, `executing_substep`, and related fields. When you send `/craft` or `/craft <goal>`, or **`/craft:approve`** while a plan is waiting, it **writes** updates (e.g. set `phase` to `investigating` or `executing`, set `initial_prompt`). Approval is **only** recognized as the exact message **`/craft:approve`** (see [workflow-state.md](workflow-state.md)). For Claude Code it also uses state to **fill** the current agent prompt template (e.g. `{{initial_prompt}}`, `{{refined_goal}}`, `{{investigation_output}}`) before returning context to the model.
- **Orchestrator** (Cursor: `.cursor/commands/craft.md`; Claude: installed skill): Tells the model to read state, run the right agent for the current phase, and **write** that agent’s output back into state (e.g. `investigation_output`, `plan_output`, `last_step_output`) and advance `phase` or `executing_substep`.
- **Result**: Each step reads “what’s been done and what’s next” from state, and writes “what I just did” back. Workflow progression does not rely on chat history; the single source of truth is the state file. Keep it gitignored so in-progress state stays local.

Full schema and transitions: [workflow-state.md](workflow-state.md).

## Agents and prompts

The default hook-driven path loads prompts for **investigation**, **planning**, **execution** (writer → optional review → chore → test runner), plus **diagnose** and **compact** when you use those commands. Other prompt files under `.craft/prompts/` (e.g. documentation, scope creep, context helper) are there for you to use or wire into your orchestration; they are not all injected automatically by `workflow.sh`.

1. **Investigator** — Explore codebase and context; feeds Planner.
2. **Planner** — Deconstructs the loose prompt into a plan (pieces, order, acceptance criteria); consumes Investigator output.
3. **Writer** — Implements code (separate from reviewer).
4. **Reviewer** — Reviews code (not the same agent that wrote it); optional substep between writer and chore.
5. **Chore** — Polish finished work (linter, formatter, cleanup).
6. **Test runner** — Run tests and fix or report failures.
7. **Documentation** — Optional; maintain or generate docs when your team invokes it.
8. **Scope creep** — Orchestrator and prompts flag when work exceeds the approved plan; human re-approval (**`/craft:approve`**) before continuing.
9. **Context helper** — Optional; compact handoff when subagents or pieces complete (see prompts; not a default substep in the Cursor command today).

## Workflow (aligned to the job)

1. **Loose prompt** — You write a high-level prompt in your editor.
2. **Deconstruct** — Investigator runs, then Planner breaks the prompt into a plan: pieces, order, acceptance criteria per piece.
3. **Review** — Framework shows you the plan; you adjust in chat or accept by sending **`/craft:approve`**. No execution until the hook sees **`/craft:approve`** (see [workflow-state.md](workflow-state.md)).
4. **Execute (default serial)** — Each plan piece runs in order (Writer → optional Review → Chore → Test runner). Teams may **parallelize** independent pieces or investigation via subagents or worktrees; merge conventions live in [workflow-state.md](workflow-state.md).
5. **Iterate** — Continue until each piece meets acceptance criteria; chore polishes; optional reviewer pass stays separate from the writer. PRs follow single responsibility where you adopt that convention.
6. **PRs and CI** — Target state is merge-ready PRs and green CI; scope creep should trigger human approval before continuing.

## Feedback and diagnose (optional)

- **`/craft:feedback <text>`** — Appends a line to `.craft/feedback.jsonl` (prefer gitignored; capped in `workflow.sh`).
- **`/craft:diagnose`** — Sets `phase` to `diagnosing`; proposals for hooks and workflow only—**no automatic hook edits**.
- **`/craft:compact`** — Sets `phase` to `compacting`; merge themes into `.craft/possible_conventions.json`.

Details: [conventions-and-feedback.md](conventions-and-feedback.md). Promoted rules can live in **`.craft/conventions.yaml`** after human review.

---

[Documentation home](README.md) · [Concepts](concepts.md) · [Setup](setup.md)
