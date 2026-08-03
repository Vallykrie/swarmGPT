---
name: codex-swarm
description: Use when writing or editing code, tests, documentation, or other content across more than one file or roughly 20 lines; when substantial work needs delegation even as one subtask; or when the user explicitly asks to swarm, fan out, parallelize, delegate, or use Codex/ChatGPT subagents. Skip for trivial one-file edits and read-only answers.
---

# Codex Swarm

## Overview

Act as the orchestrator: decompose, route, coordinate, review, integrate, verify, and report. Delegate substantive writing to Codex subagents through native collaboration tools. Do not replace native delegation with shell dispatchers, prompt files, or external agent CLIs.

**Default rule:** Delegate before writing substantial code or content yourself. A swarm of one is valid; parallelism is an optimization, not a prerequisite.

## Quick Reference

| Situation | Action |
|---|---|
| More than one file or roughly 20 lines of writing | Delegate before editing |
| Explicit swarm, fan-out, parallelize, delegate, or Codex/ChatGPT subagent request | Use this workflow |
| Substantial but sequential work | Delegate one coherent subtask |
| Trivial edit in one file | Work locally |
| Read-only answer, planning, or review | Work locally unless explicitly delegated |
| Ambiguous, risky, architectural, debugging, or integration-sensitive work | `gpt-5.6-sol`, `reasoning_effort: medium` |
| Easy, isolated, boilerplate, mechanical, documentation, straightforward tests, or bulk work | `gpt-5.6-luna`, `reasoning_effort: max` |
| Agent needs correction | Send a focused follow-up to the same agent |
| Agent is stuck or unsuitable | Reassign only the affected subtask |

Never ask the user to choose a model. Apply the mapping exactly and automatically. In particular, do not reduce the easy model's effort: `gpt-5.6-luna` always receives `reasoning_effort: max` under this skill.

## Workflow

### 1. Establish scope

1. Inspect the repository, applicable instructions, current changes, and available verification commands.
2. Identify the deliverables, shared dependencies, integration points, and acceptance criteria.
3. Reserve orchestration work for the host: decomposition, coordination, review, integration decisions, final verification, the run log, and the user report.
4. Keep a shared or integration-sensitive file with the host or assign it to exactly one explicit owner.

Do not use delegation to broaden authorization. Subagents inherit the task's safety, permission, and scope constraints.

### 2. Decompose without overlapping writes

Split work along independent file, module, test, documentation, or research boundaries.

- Give every write task an exclusive set of paths. No two agents may modify the same file.
- Agents may read shared files for context.
- Do not make concurrent tasks depend on outputs that do not yet exist. Dispatch dependent work only after its prerequisite is complete.
- Keep a genuinely sequential core together. If it is still substantial, dispatch it as one subtask.
- Prefer a few coherent tasks over tiny fragments that increase coordination cost.

Before dispatch, check that all required files have one owner and no file has two owners.

### 3. Route automatically

Use these exact overrides:

| Work profile | `model` | `reasoning_effort` |
|---|---|---|
| Reasoning-heavy, ambiguous, risky, architecture, debugging, tricky refactors, or integration-sensitive | `gpt-5.6-sol` | `medium` |
| Easy, isolated, boilerplate, mechanical, documentation, straightforward tests, or bulk | `gpt-5.6-luna` | `max` |

Classify each subtask by its hardest material requirement. Route high-cost mistakes or cross-system judgment to `gpt-5.6-sol`; route well-specified production to `gpt-5.6-luna`. Do not substitute another model or effort level because it seems available, cheaper, or customary.

If a required model is unavailable or a spawn rejects its model/effort override, perform only one availability/error check for that routing failure. Mark the affected subtask blocked, report the unavailable exact mapping, and request explicit user authorization before using any fallback. Do not retry in a loop and never silently substitute a model or effort level.

### 4. Write self-contained dispatch prompts

Every subagent starts without relying on conversational inference. Include the necessary task-local context and use this compact contract:

```text
Goal: <one concrete outcome>
Read: <exact context paths and applicable instructions>
Own: <exact writable paths; touch nothing else>
Requirements: <behavior, conventions, constraints, and safety limits>
Acceptance: <observable completion criteria and verification commands>

When done, report:
- STATUS: complete | blocked
- FILES: every file changed, or none
- VERIFICATION: commands/checks run and results
- ASSUMPTIONS: material assumptions, or none
- BLOCKERS: unresolved blockers, or none
- RESULT: concise summary
```

For read-only tasks, replace `Own` with `Write: none` and require evidence or source locations in `RESULT`.

### 5. Dispatch and keep slots full

Use native collaboration primitives directly:

- Use `spawn_agent` to launch independent tasks with the selected `model` and `reasoning_effort`. Every spawn that sets these overrides must also set `fork_turns` explicitly to `"none"` or a positive bounded turn count, because full-history forks reject model overrides. Prefer `fork_turns: "none"`; the prompt is already self-contained.
- Respect the currently available concurrency slots, including the host. Launch independent tasks immediately up to capacity.
- Use `wait_agent` for bounded waits of at most 60 seconds (`timeout_ms <= 60000`) and `list_agents` to inspect state. As work finishes, immediately refill open slots with ready tasks. If a longer overall wait is necessary, update the user before each additional bounded wait.
- Use `send_message` for information needed by a running agent and `followup_task` for a focused correction or additional pass.
- Use `interrupt_agent` only when continuing would be harmful, obsolete, or outside scope.

Continue useful local orchestration while agents run: inspect dependencies, prepare integration checks, review completed output, and keep the task map current. Send concise user updates during ongoing work so more than 60 seconds never pass without communication.

Do not claim unlimited parallelism or launch work beyond available capacity.

### 6. Handle failures with evidence

When a subtask fails or returns incomplete work:

1. Inspect its report, diffs, diagnostics, and verification output.
2. Determine whether the failure is local to the task, caused by missing context, or an integration issue.
3. Send a focused follow-up to the same agent when it can repair its work efficiently. Include the concrete failing evidence and retain the same ownership boundary.
4. Reassign only when the original agent cannot continue or the task needs different expertise.
5. Update downstream tasks if an assumption or interface changed.

Never silently redo all delegated work locally. Small integration seams may be fixed by the host when they remain within scope; substantive rewrites return to an explicitly owned subtask.

### 7. Review and integrate

Treat agent completion as a handoff, not proof of correctness.

1. Inspect every changed file and compare it with its prompt and ownership boundary.
2. Check compatibility across subtasks, especially imports, interfaces, naming, generated artifacts, and shared assumptions.
3. Run integration-level verification appropriate to the repository: focused tests first, then broader tests, type checks, lint, builds, or artifact inspection as risk warrants.
4. Resolve failures using the evidence-driven follow-up loop.
5. Do not claim completion until the integrated result satisfies the original request.

The run log is an audit trail, not a substitute for review or verification.

### 8. Persist the run log

When project writes are authorized and the project log path is writable, write `.codex-swarm/logs/<ISO-timestamp>.md` for every swarm run. Use a filesystem-safe UTC timestamp such as `2026-08-03T05-45-09Z`.

For read-only requests, path-restricted tasks, or unwritable projects, do not create the directory or log without authorization. Report that persistent logging is blocked by the request or filesystem boundary and include the same compact audit fields in the final response instead. This is a terminal logging fallback, not permission to write elsewhere.

```markdown
# codex-swarm run <ISO-timestamp>

<One-paragraph summary of the request, decomposition, outcome, and failures.>

- **Wall-clock:** <duration>
- **Integration verification:** <commands/checks and results>

## Subtasks

### <task name> — complete | blocked | failed
- **Model:** gpt-5.6-sol | gpt-5.6-luna
- **Reasoning effort:** medium | max
- **Files:** <paths or none>
- **Verification:** <checks and results>
- **Result:** <one or two sentences>
```

Record failed and reassigned attempts rather than erasing them. Include every subtask, exact routing, status, files, verification, and result, plus total wall-clock time and integration verification.

### 9. Report to the user

Lead with the integrated outcome. Summarize material changes, verification, any remaining blockers, and per-subtask status. Include the run-log path when persisted; otherwise state why persistence was blocked and include the compact audit inline. Do not dump raw agent transcripts.

## Rationalizations to Reject

| Rationalization | Reality |
|---|---|
| "It is faster to write locally." | Substantive writing belongs to subagents; the host spends its time on scope, review, and integration. |
| "The task does not parallelize." | A single delegated subtask is a valid swarm. |
| "I need fine control." | Encode control in exact ownership, requirements, acceptance criteria, and review. |
| "The user did not explicitly ask." | The size trigger makes delegation the default; explicit invocation is not required. |
| "I already started writing." | Stop and dispatch the remaining substantive work; sunk cost does not change the workflow. |
| "The small model should use low effort." | The required easy-task mapping is exactly `gpt-5.6-luna` with `reasoning_effort: max`. |

## Red Flags

Stop and correct course if any of these occur:

- Writing substantial artifacts locally before delegation
- Waiting for parallelism before delegating a substantial single task
- Asking the user which model or effort to use
- Routing to anything other than the two exact model/effort pairs
- Spawning with model overrides while omitting bounded `fork_turns`
- Looping on an unavailable model or silently substituting a fallback
- Giving agents overlapping write ownership
- Dispatching prompts that depend on unstated conversation context
- Exceeding available concurrency or leaving ready slots idle without reason
- Calling `wait_agent` for more than 60 seconds or extending the wait without a user update
- Treating an agent's success report as sufficient review
- Retrying blindly, reassigning without evidence, or silently redoing the work locally
- Omitting the persistent run log when authorized and writable, or writing one when the request is read-only/path-restricted
- Claiming completion before integration-level verification

All red flags require returning to the relevant workflow step before proceeding.
