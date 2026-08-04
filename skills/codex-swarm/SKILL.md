---
name: codex-swarm
description: Use BEFORE writing or editing code, tests, docs, or other content yourself — whenever the writing spans more than one file or more than ~20 lines. Delegating the writing to Codex sessions via the `codex` CLI is the default; you orchestrate. Also use when the user asks to swarm/fan out/parallelize work across Codex or GPT, or invokes /codex-swarm. Triggers include implementing a feature, scaffolding or creating files, refactors, migrations, bulk edits, boilerplate, test suites, documentation, and multi-topic research. Skip only for trivial edits (a few lines in one file) or when the codex CLI is unavailable.
---

# codex-swarm

You are the **orchestrator**: you plan, decompose, route, and review. `codex
exec` sessions running GPT-5.6 do the writing and the token-heavy bulk work.
**Writing substantial code or content yourself instead of dispatching it is a
violation of this workflow** — the user installed this skill precisely so that
Codex does the writing on their ChatGPT plan instead of burning your context.

Verified against Codex CLI **0.146.0**. Re-check `codex exec --help` if flags
seem wrong — this CLI changes fast.

## Delegate by default

Before you write anything, apply this rule:

- Writing work that spans **more than one file or more than ~20 lines** →
  dispatch it to Codex via this skill. This holds even when it is a single
  coherent task: **a swarm of one subtask is a normal, valid run.** Parallel
  fan-out is an optimization, not a precondition.
- Trivial edits (a few lines in one file), pure planning/review, and answers
  that need no artifacts → do them yourself.
- You still own everything around the writing: decomposition, prompts, model
  routing, integration, verification, and the final report.

If you catch yourself mid-task writing a file Codex could have written, stop,
turn the remaining work into subtask prompts, and dispatch.

| Excuse for writing it yourself | Reality |
|--------------------------------|---------|
| "It's faster if I just write it" | Dispatch overhead is seconds; Codex writes while your context stays free for review. |
| "This task doesn't split into parallel parts" | A single-subtask dispatch is a valid swarm. Splitting is optional. |
| "I need fine control over this code" | Put the control in the subtask prompt (exact paths, conventions, constraints), then review the result. |
| "The user didn't ask for a swarm" | The user installed this skill so Codex does the writing by default. Explicit invocation is not required. |
| "I'm already halfway through writing it" | Sunk cost. Dispatch the remaining files. |

## Step 0 — Preflight

1. `command -v codex` — if missing, stop and tell the user to install the
   Codex CLI (`npm install -g @openai/codex`) and run `codex login`.
2. Locate the dispatcher script, in this order:
   - `${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh` (plugin install)
   - `scripts/dispatch.sh` next to this SKILL.md (standalone skill install)
   - `$(dirname "$0")/../../scripts/dispatch.sh` (repo checkout)
3. If `codex exec` later fails every job with an auth error, stop and tell the
   user to run `codex login` in a terminal. Never paste a key into chat.

## Step 1 — Resolve the sandbox mode

The `/codex-swarm` command (or the user directly) supplies one of four modes.
If none was given, use `default`.

| Mode | Dispatch flag | What the Codex jobs may do |
|------|---------------|----------------------------|
| `default` | mirror the host | If you are running with auto-accepted/bypassed permissions, use `--auto`. If your own edits require user review, use `--readonly`. |
| `auto` | `--auto` | `--sandbox workspace-write`: write anywhere in the project, no network, no approval prompts. This is the normal mode for write tasks. |
| `readonly` | `--readonly` | `--sandbox read-only`: read and analyze only. Jobs report findings or emit patches for you to apply. Use for research and for review-mode hosts. |
| `yolo` | `--yolo` | `--dangerously-bypass-approvals-and-sandbox`: no sandbox at all. Only when the user explicitly asks and the environment is already isolated (container/VM). |

`codex exec` is non-interactive: there is no TTY to approve a gated command,
so a job that needs approval stalls until the timeout. That is why the modes
are sandbox levels rather than approval policies. Never ask the user to pick a
mode mid-run; resolve it yourself from the rule above.

## Step 2 — Decompose the task

Split the task into **independent** subtasks:

- No two subtasks may write the same file or depend on each other's output.
  Prefer splits along existing boundaries: different files, modules,
  directories, or research topics.
- If a task has a genuinely sequential core, keep that core for yourself and
  swarm only the independent parts.
- Each subtask prompt must be **fully self-contained**. The Codex sessions
  share nothing — no conversation history, no knowledge of the other subtasks.
  Include in every prompt: the goal, the exact file paths to read/write,
  relevant constraints/conventions, and the expected output format.
- For write tasks, tell each subtask exactly which files it owns and to touch
  nothing else. End each prompt with: "When done, print a line starting with
  `TOUCHED:` listing every file you created or modified, then a one-paragraph
  summary of what you did."
- Typical fan-out is 1–10 subtasks. One subtask is fine when the task is a
  single coherent unit — dispatch it anyway rather than writing it yourself.

Before dispatch, check the ownership map: every required file has exactly one
owner, and no file has two.

## Step 3 — Route a model and effort per subtask

Choose per subtask, automatically — never ask the user which model:

| Work profile | `MODEL:` | `EFFORT:` |
|---|---|---|
| Reasoning-heavy or ambiguous: debugging, architecture, tricky refactors, integration-sensitive changes, anything where a wrong answer is expensive | `gpt-5.6-sol` | `medium` |
| Bulk, boilerplate, mechanical: scaffolding, mass renames, format conversions, test scaffolding, doc generation, file summarization, straightforward CRUD | `gpt-5.6-luna` | `max` |

Classify each subtask by its hardest material requirement. These are exact
Codex model slugs — pass them verbatim. Do not lower Luna's effort because the
task looks easy; `gpt-5.6-luna` always gets `max` under this skill. Valid
efforts are `low`, `medium`, `high`, `xhigh`, `max`.

If a model is rejected by the CLI (every job for it fails immediately), check
once with `codex exec --help` / the user's `~/.codex/config.toml`, then report
the failure and ask before substituting. Never silently swap models.

## Step 4 — Write the subtask files

Create one prompt file per subtask in a temp directory (e.g.
`$(mktemp -d)/01-slug.prompt.md`). Format — model header, optional effort
header, blank line, then the prompt:

```
MODEL: gpt-5.6-luna
EFFORT: max

Create src/parser/tokens.ts ...
```

Name files `NN-short-slug.prompt.md`; the basename (minus `.prompt.md`)
becomes the subtask name in logs. A useful prompt skeleton:

```text
Goal: <one concrete outcome>
Read: <exact context paths and conventions to follow>
Own: <exact writable paths; touch nothing else>
Requirements: <behavior, conventions, constraints>
Acceptance: <observable criteria and the verification command to run>

When done, print a line starting with TOUCHED: listing every file you created
or modified, then a one-paragraph summary.
```

For read-only subtasks replace `Own:` with `Write: none` and require source
locations or evidence in the summary.

## Step 5 — Dispatch (always parallel)

**If the `codex-dispatcher` subagent is available** (plugin install), delegate
to it: pass the task-file paths, the mode flag, and the project root. It runs
the script, waits, writes the run log, and returns only a summary — keeping
raw Codex output out of your context.

**Otherwise** run the script yourself from the project root, in one call, with
a Bash timeout of at least 20 minutes:

```bash
bash "$DISPATCH" --auto --timeout 20m 01-*.prompt.md 02-*.prompt.md
```

Every job launches concurrently and the script blocks until all finish. Its
stdout is a short status table plus the run directory
(`.codex-swarm/logs/<ts>/`). Read `results.tsv` and each `<name>.last` (the
agent's final message — small). **Never `cat` a `<name>.out` file**; those are
full event streams and will flood your context. For failures, read the last
few lines of `<name>.err`.

Add `--jobs N` if the user asks you to limit concurrency; the default is
unlimited.

## Step 6 — Verify, integrate, report

A subtask's own success claim is a handoff, not proof.

1. Read the actual diff for every file a subtask claims it touched.
2. Check cross-subtask compatibility: imports, interfaces, naming, shared
   assumptions, generated artifacts.
3. Run integration-level verification: focused tests first, then broader
   tests, type checks, lint, or build as risk warrants.
4. On failure, re-dispatch the affected subtask with the concrete failing
   evidence in the prompt. Fix only small integration seams yourself;
   substantive rewrites go back to a subtask.
5. Ensure the run log exists at `.codex-swarm/logs/<ISO-timestamp>.md` (the
   dispatcher subagent writes it; write it yourself if you dispatched
   directly). Same timestamp as the run directory:

```markdown
# codex-swarm run <ts>

<One paragraph: what was dispatched, how many subtasks, which models,
what passed/failed, total wall-clock time.>

- **Mode**: auto | readonly | yolo
- **Wall-clock**: NNs total
- **Integration verification**: <commands and results>

## Subtasks

### <name> — ok | FAIL
- **Model**: <slug> / <effort>
- **Duration**: NNs
- **Files touched**: <from TOUCHED:, or none>
- **Result**: <one or two sentences>
```

If the project is read-only or the request forbids writes, skip the log file
and put the same fields inline in your final message instead.

6. Report the integrated outcome, material changes, verification results, any
   remaining blockers, and the run-log path. Do not dump agent transcripts.

## Red flags

Stop and return to the relevant step if any of these happen:

- Writing substantial files locally before dispatching
- Waiting for parallelism before dispatching a single substantial task
- Asking the user which model or effort to use
- Two subtasks owning the same file
- Prompts that assume conversation context the Codex session never saw
- Dispatching a write task in `readonly` mode, or `yolo` without an explicit ask
- `cat`-ing a `.out` file into your context
- Treating a subtask's "done" as verification
- Claiming completion before integration-level checks pass
