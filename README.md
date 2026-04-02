# Craft Choreographer
Carefully constructed workflows to support systemic development in the LLM-assisted era

## Vision

Craft Choreographer tackles **sprawl and context rot** by decomposing prompts into focused, manageable workflows using a divide-and-conquer strategy with specialized agents.

## The Core Problem

When working with LLMs, prompts grow unwieldy:
- **Scope creep**: Tasks expand beyond original intent
- **Context rot**: Too much context dilutes focus and quality
- **Sprawl**: Single monolithic prompts become unmaintainable

## The Solution

We're building a **framework** that:

1. **Starts from a very loose prompt** — You give a high-level, vague ask in your editor (Cursor or Claude Code).
2. **Deconstructs it** — An LLM (using agents or workflow pieces) breaks down the prompt into a concrete plan: discrete pieces of work.
3. **Asks you for review** — The framework presents the broken-down plan. No execution until you confirm.
4. **Executes after confirmation** — Once you approve the plan, the orchestrator runs each piece (Writer → optional Review → Chore → Test runner) in order by default. You can **fan out** parallel investigators or parallel piece work via editor subagents/worktrees; results **write back** into `.craft/state.json` (see `docs/workflow-state.md`).
5. **Runs until pieces meet acceptance** — Ralph-style persistence can ensure each piece is completed; chore polishes; optional **Reviewer** prompt gives a separate pass from the Writer.
6. **Continues until PRs are ready** — The flow runs until the project has PRs that pass CI (with auto-fix of CI failures when possible) and are ready for your review.

**End state:** PRs that pass CI and are ready for human review.

### Design decisions

- **Staying focused** — We structure agents and prompts so decomposition stays focused; that keeps the plan reviewable and reduces bad or incomplete plans.
- **Order** — Agents define the order logically (e.g. data layer before frontend; static page → frontend first). Dependencies come from the same reasoning that decomposes the work.
- **Done** — Each piece has acceptance criteria, defined by the agents during decomposition. That defines when a piece is “done” and what chore/CI can check.
- **PRs** — Single responsibility: one PR per logical unit (e.g. one for migration, one for API, one for frontend for a CRUD feature). Agents apply this when breaking up work.
- **Scope creep** — If work goes outside the approved plan, the framework requires human approval before continuing (re-gate).
- **Deconstruct** — A dedicated **Planner** agent produces the plan. It consumes output from the **Investigation** agent. Investigator = understand codebase/context; Planner = break down the work (pieces, order, acceptance criteria).

Further detail lives in `docs/` (see [Docs](#docs) below).

## Setup

### Use `/craft` anywhere (recommended)

Install once, then use `/craft` (and `/craft <goal>`) in **any** project—no per-repo setup. The workflow runs from your clone; state lives in the current project’s `.craft/state.json`.

1. **Clone this repo once** (e.g. `~/craft-choreographer`).
2. **Install globally** (Cursor + Claude Code):
   ```bash
   ~/craft-choreographer/scripts/install-global.sh
   ```
   This sets **Cursor** (`~/.cursor/hooks.json`, `~/.cursor/commands/craft.md`) and **Claude Code** (`~/.claude/settings.json`, `~/.claude/skills/craft/`) so `/craft` is available in every project. After you `git pull` this repo, refresh the copied orchestrator files with:
   ```bash
   ~/craft-choreographer/scripts/install-global.sh update
   ```
   Run `install-global.sh help` for all commands. First-time install does not overwrite existing hooks; `update` only refreshes the Cursor command and Claude skill (not hooks).
3. **Open any repo** and type `/craft` or `/craft <goal>`. On first use, `.craft/` and state are created in that project automatically; prompts and logic come from your clone.

**Dependencies:** `jq` (e.g. `brew install jq` on macOS). No need to nest projects under this repo or run init per project.

### Optional: per-project init

If you prefer project-local config (e.g. to commit Cursor/Claude wiring so teammates get `/craft` without a global install), run from the clone:

```bash
~/craft-choreographer/scripts/init-project.sh /path/to/your-project
```

That creates `.craft/` (wrapper + symlink to prompts) and copies hook/command files into the project. State is still per-project in `.craft/state.json`.

### Manual per-project setup

1. **Cursor**: Put `.cursor/hooks.json` and `.cursor/commands/craft.md` in the project; hook runs `.craft/workflow.sh`.
2. **Claude Code**: Put `.claude/settings.json` with a `UserPromptSubmit` hook that runs `.craft/workflow.sh`.
3. **State**: `.craft/state.json` is created on first `/craft` and should stay gitignored.

## How `.craft/state.json` is used

The state file is the workflow’s **memory**: it persists between steps and between runs so the framework always knows where you are and what to do next.

- **Workflow script** (`.craft/workflow.sh`): On each hook run it **reads** state to get `phase`, `initial_prompt`, `investigation_output`, `plan_output`, `piece_index`, `executing_substep`, etc. When you send `/craft` or approve the plan, it **writes** updates (e.g. set `phase` to `investigating` or `executing`, set `initial_prompt`). For Claude Code it also uses state to **fill** the current agent prompt template (e.g. inject `{{initial_prompt}}`, `{{investigation_output}}`) before returning context to the model.
- **Orchestrator** (Cursor: `.cursor/commands/craft.md`): Tells the model to read state, run the right agent for the current phase, and **write** that agent’s output back into state (e.g. `investigation_output`, `plan_output`, `last_step_output`) and advance `phase` or `executing_substep` so the next step runs correctly.
- **Result**: Each step reads “what’s been done and what’s next” from state, and writes “what I just did” back. No workflow logic lives in the chat history; the single source of truth is the state file. It’s gitignored so your in-progress state stays local and isn’t committed when you use the repo across machines.

See [docs/workflow-state.md](docs/workflow-state.md) for the full state schema and phase transitions.

## Agents used in the flow

The framework uses these agents throughout the job (deconstruct, spawn, execute, polish, CI). They are the building blocks that assist each step.

1. **Investigator** — Explore codebase and context; feeds Planner.
2. **Planner** — Deconstructs the loose prompt into a plan (pieces, order, acceptance criteria); consumes Investigator output.
3. **Writer** — Implement code (separate from reviewer)
3. **Reviewer** — Review code (not the same agent that wrote it)
4. **Chore work (linter, etc.)** — Polish finished work; automated cleanup
5. **Test runner and fixer** — Run tests, fix failures; part of CI auto-fix
6. **General documentation** — Generate/maintain docs
7. **Scope creep detector** — Identify when work exceeds the approved plan; requires human approval before continuing
8. **Context helper** — Capture problem state, decisions, current state when a subagent completes

### Open questions

- Which of these are required for the job vs. optional?
- Clear boundaries between agents?
- How to prevent agent proliferation from creating more sprawl?

## Workflow (aligned to job)

1. **Loose prompt** — You write a high-level prompt in your editor.
2. **Deconstruct** — Investigator runs, then Planner (using Investigator output) breaks the prompt into a plan: pieces, order, acceptance criteria per piece.
3. **Review** — Framework shows you the plan; you confirm or adjust. No spawns until you approve.
4. **Execute (default serial)** — The orchestrator runs each plan piece in order (Writer → optional Review → Chore → Test runner). Teams may **parallelize** independent pieces or investigation via subagents/worktrees; outputs merge back through `.craft/state.json` per `docs/workflow-state.md`.
5. **Iterate** — Work continues until each piece meets acceptance criteria (Ralph-style where useful); chore polishes; optional reviewer pass is separate from the writer. PRs follow single responsibility. Repeat until all pieces are done.
6. **PRs + CI** — Flow continues until PRs exist, pass CI (auto-fix when possible), and are ready for your review. Scope creep → human approval required before continuing.

## Docs

| Doc | Purpose |
|-----|---------|
| [docs/workflow-state.md](docs/workflow-state.md) | State machine, phases, and state schema for the workflow. |
| [docs/question-flow-constraints.md](docs/question-flow-constraints.md) | One-question / limited-question flow to avoid context loss. |

`docs/archive/` is gitignored so you can keep local design references (e.g. vetting, memory-and-reflection) there without publishing them when you use the repo across machines.
