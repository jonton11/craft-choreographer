# Craft Choreographer

Carefully constructed workflows to support systemic development in the LLM-assisted era.

## Vision

Craft Choreographer tackles **sprawl and context rot** by decomposing prompts into focused, manageable workflows using a divide-and-conquer strategy with specialized agents.

## The core problem

When working with LLMs, prompts grow unwieldy:

- **Scope creep**: Tasks expand beyond original intent
- **Context rot**: Too much context dilutes focus and quality
- **Sprawl**: Single monolithic prompts become unmaintainable

## The framework

We're building a **framework** that:

1. **Starts from a very loose prompt** — You give a high-level, vague ask in your editor (Cursor or Claude Code).
2. **Deconstructs it** — An LLM (using agents or workflow pieces) breaks down the prompt into a concrete plan: discrete pieces of work.
3. **Asks you for review** — The framework presents the broken-down plan. No execution until you confirm.
4. **Executes after confirmation** — Once you send **`/craft:approve`**, the orchestrator runs each piece (Writer → optional Review → Chore → Test runner) in order by default. You can **fan out** parallel investigators or parallel piece work via editor subagents/worktrees; results **write back** into `.craft/state.json` (see [docs/workflow-state.md](docs/workflow-state.md)).
5. **Runs until pieces meet acceptance** — Ralph-style persistence can ensure each piece is completed; chore polishes; optional **Reviewer** prompt gives a separate pass from the Writer.
6. **Continues until PRs are ready** — The flow runs until the project has PRs that pass CI (with auto-fix of CI failures when possible) and are ready for your review.

**End state:** PRs that pass CI and are ready for human review.

Further rationale and design decisions: [docs/concepts.md](docs/concepts.md).

**Editors:** Cursor and Claude Code. **Requirement:** [`jq`](https://jqlang.github.io/jq/) (e.g. `brew install jq` on macOS).

## Quick start

1. Clone this repository once (for example `~/craft-choreographer`).
2. Install globally:

   ```bash
   ~/craft-choreographer/scripts/install-global.sh
   ```

3. Open any project and run **`/craft`** or **`/craft <goal>`**. Approve plans with exactly **`/craft:approve`**.

After `git pull` in this repo, refresh the Cursor command and Claude skill (hooks are left as-is):

```bash
~/craft-choreographer/scripts/install-global.sh update
```

Optional: commit wiring into a repo with `scripts/init-project.sh`—see [docs/setup.md](docs/setup.md).

## Documentation

**[docs/README.md](docs/README.md)** is the index. In short:

| Doc | Purpose |
|-----|---------|
| [docs/concepts.md](docs/concepts.md) | Why it exists, how the framework behaves, design decisions. |
| [docs/setup.md](docs/setup.md) | Install, update, per-project init, manual setup. |
| [docs/using-the-workflow.md](docs/using-the-workflow.md) | State file, agents, user-facing flow, feedback commands. |
| [docs/workflow-state.md](docs/workflow-state.md) | Phases and full state schema. |
| [docs/conventions-and-feedback.md](docs/conventions-and-feedback.md) | Feedback log, diagnose, compact, conventions. |
| [docs/question-flow-constraints.md](docs/question-flow-constraints.md) | Limited-question flow to protect context. |

`docs/archive/` is gitignored for local design notes you do not want to publish.
