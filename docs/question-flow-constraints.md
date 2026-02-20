# Question flow constraints

Multiple questions in one prompt create branching paths and context loss. Craft Choreographer enforces a limited-question flow.

## Approach

1. **Hybrid enforcement**: Pre-processing detects multiple questions and decomposes into a sequential task list; agents follow one focused task at a time in dedicated context windows.
2. **One primary task + optional clarifications**: One primary objective per agent interaction; clarifications allowed only if they directly enable that task and are resolved before proceeding (no branching).
3. **Multi-part questions**: Plan-ahead decomposition—generate a full subtask list upfront, execute sequentially, re-inject parent plan context into each subtask so related parts stay coherent.

## Pattern

- Input with multiple questions → plan-ahead decomposition → sequential workflow.
- Each agent gets a dedicated context window and receives only the structured context it needs.
- No parallel question branches; one path, ordered steps.
