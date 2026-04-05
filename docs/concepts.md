# Concepts

## Vision

Craft Choreographer tackles **sprawl and context rot** by decomposing prompts into focused, manageable workflows using a divide-and-conquer strategy with specialized agents.

## The core problem

When working with LLMs, prompts grow unwieldy:

- **Scope creep**: Tasks expand beyond original intent
- **Context rot**: Too much context dilutes focus and quality
- **Sprawl**: Single monolithic prompts become unmaintainable

## The solution

We're building a **framework** that:

1. **Starts from a very loose prompt** — You give a high-level, vague ask in your editor (Cursor or Claude Code).
2. **Deconstructs it** — An LLM (using agents or workflow pieces) breaks down the prompt into a concrete plan: discrete pieces of work.
3. **Asks you for review** — The framework presents the broken-down plan. No execution until you confirm.
4. **Executes after confirmation** — Once you send **`/craft:approve`**, the orchestrator runs each piece (Writer → optional Review → Chore → Test runner) in order by default. You can **fan out** parallel investigators or parallel piece work via editor subagents or worktrees; results **write back** into `.craft/state.json` (see [workflow-state.md](workflow-state.md)).
5. **Runs until pieces meet acceptance** — Ralph-style persistence can ensure each piece is completed; chore polishes; an optional **Reviewer** pass is separate from the Writer.
6. **Continues toward merge-ready work** — The intended end state is PRs that pass CI (with auto-fix when possible) and are ready for human review. Achieving that depends on your repo’s CI and how you use the test and chore prompts—not on automation built into this repository alone.

**Target end state:** PRs that pass CI and are ready for human review.

### Design decisions

- **Staying focused** — Agents and prompts are structured so decomposition stays focused; that keeps the plan reviewable and reduces bad or incomplete plans.
- **Order** — Agents define the order logically (e.g. data layer before frontend). Dependencies come from the same reasoning that decomposes the work.
- **Done** — Each piece has acceptance criteria, defined during decomposition. That defines when a piece is “done” and what chore and tests can check.
- **PRs** — Single responsibility: one PR per logical unit (e.g. one for migration, one for API, one for frontend for a CRUD feature). Agents apply this when breaking up work.
- **Scope creep** — If work goes outside the approved plan, the framework expects human approval before continuing (re-gate).
- **Deconstruct** — A dedicated **Planner** produces the plan. It consumes output from the **Investigator**. Investigator = understand codebase and context; Planner = break down the work (pieces, order, acceptance criteria).

### Open questions

- Which agents are required for a given job vs. optional?
- Clear boundaries between agents?
- How to prevent agent proliferation from creating more sprawl?

Next: [Setup](setup.md) · [Using the workflow](using-the-workflow.md)
