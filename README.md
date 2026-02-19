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
4. **Spawns subagents after confirmation** — Once you approve the plan, the framework spawns subagents to work on each piece.
5. **Runs subagents in order until done** — Subagents work on each piece in the right order. Ralph-style persistence can ensure each piece is completed; other agents (e.g. chore) take finished work and produce a polished version.
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

1. **Cursor**: Ensure `.cursor/hooks.json` and `.cursor/commands/craft.md` are in the project. The hook runs `.craft/workflow.sh` on every prompt; the `/craft` command is available in chat.
2. **Claude Code**: Ensure `.claude/settings.json` includes the `UserPromptSubmit` hook that runs `.craft/workflow.sh`. No separate command: type `/craft` (or `/craft <goal>`) in the prompt; the hook injects the right agent context.
3. **Dependencies**: The workflow script uses `jq` for JSON. Install if needed (e.g. `brew install jq` on macOS).
4. **State**: `.craft/state.json` is gitignored; it is created automatically when you run `/craft`. Do not commit it.

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
4. **Spawn** — Framework spawns subagents per piece (or per role per piece), in the order defined by the plan.
5. **Execute** — Subagents work until each piece meets its acceptance criteria (Ralph-style where useful); chore polishes finished work. PRs follow single responsibility (e.g. one PR per logical unit). Repeat until all pieces are done.
6. **PRs + CI** — Flow continues until PRs exist, pass CI (auto-fix when possible), and are ready for your review. Scope creep → human approval required before continuing.

## Docs

| Doc | Purpose |
|-----|---------|
| [docs/workflow-state.md](docs/workflow-state.md) | State machine, phases, and state schema for the workflow. |
| [docs/question-flow-constraints.md](docs/question-flow-constraints.md) | One-question / limited-question flow to avoid context loss. |

`docs/archive/` is gitignored so you can keep local design references (e.g. vetting, memory-and-reflection) there without publishing them when you use the repo across machines.
