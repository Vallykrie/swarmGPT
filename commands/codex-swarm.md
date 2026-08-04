---
description: Swarm a task across parallel Codex (codex exec) sessions with automatic decomposition and model routing
argument-hint: [default|auto|readonly|yolo] [task...]
---

Run the **codex-swarm** skill (`skills/codex-swarm/SKILL.md` in this plugin —
read it now and follow it exactly).

Arguments given: `$ARGUMENTS`

Interpret them as follows:

- If the first word is `default`, `auto`, `readonly`, or `yolo`, that is the
  **sandbox mode**; everything after it is the task description.
- Otherwise the mode is `default` and the whole argument string is the task.
- Mode meanings (details in the skill's Step 1):
  - `default` — mirror your own current permission mode: auto-accept host →
    dispatch with `--auto`; review-mode host → dispatch with `--readonly`.
  - `auto` — `--sandbox workspace-write`: Codex may write inside the project.
  - `readonly` — `--sandbox read-only`: analysis and research only.
  - `yolo` — `--dangerously-bypass-approvals-and-sandbox`. Only on explicit
    request, in an already-isolated environment.

If no task description remains, treat the mode as set for this conversation,
confirm it in one line, and apply it when the user gives the next swarmable
task. Do not ask which model to use for any subtask — routing is your job.

Decompose the task, route models, dispatch all subtasks in parallel via the
`codex-dispatcher` subagent (it calls `${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh`),
review the results, ensure the run log exists at
`.codex-swarm/logs/<ISO-timestamp>.md`, then integrate, verify, and report.
