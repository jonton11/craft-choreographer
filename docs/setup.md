# Setup

## Use `/craft` anywhere (recommended)

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

## Optional: per-project init

If you prefer project-local config (e.g. to commit Cursor/Claude wiring so teammates get `/craft` without a global install), run from the clone:

```bash
~/craft-choreographer/scripts/init-project.sh /path/to/your-project
```

That creates `.craft/` (wrapper + symlink to prompts) and copies hook and command files into the project. State is still per-project in `.craft/state.json`.

## Manual per-project setup

1. **Cursor**: Put `.cursor/hooks.json` and `.cursor/commands/craft.md` in the project; the hook runs `.craft/workflow.sh`.
2. **Claude Code**: Put `.claude/settings.json` with a `UserPromptSubmit` hook that runs `.craft/workflow.sh`.
3. **State**: `.craft/state.json` is created on first `/craft` and should stay gitignored.

See also: [workflow-state.md](workflow-state.md) · [Using the workflow](using-the-workflow.md)
