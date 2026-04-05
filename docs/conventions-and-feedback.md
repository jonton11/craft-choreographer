# Conventions, feedback, and diagnose

## Files

| Path | Role |
|------|------|
| `.craft/feedback.jsonl` | Append-only lines (local; gitignored). Capped in `workflow.sh`. |
| `.craft/possible_conventions.json` | Candidate conventions; updated after `/craft:compact`. |
| `.craft/conventions.yaml` | Promoted rules you commit after review. |

## Commands

| Command | Effect |
|---------|--------|
| `/craft:feedback <text>` | Appends one JSON line to `feedback.jsonl`. |
| `/craft:diagnose` | Sets `phase` to `diagnosing`. Proposals only — **no automatic hook edits**. |
| `/craft:compact` | Sets `phase` to `compacting`; merge feedback into `possible_conventions.json` per prompt. |

Hook files (`.cursor/hooks.json`, `.claude/settings.json`, `.craft/workflow.sh`) change only with **explicit human approval** (e.g. PR review).
