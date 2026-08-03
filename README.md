# codex-swarm

> **Subagents do the substantive writing. The host Codex agent orchestrates and verifies.**

`codex-swarm` is a Codex-native skill for delegating substantial work through Codex collaboration tools. For changes spanning more than one file or roughly 20 lines, the host decomposes the request, routes each independent subtask to the prescribed model, coordinates bounded parallel execution, reviews every result, verifies the integrated output, and records a persistent audit log.

The skill uses native subagents—no shell dispatcher, prompt-file protocol, external agent CLI, or third-party model session is required. A single delegated subtask is valid when the work is substantial but cannot be parallelized.

## What it does

The host Codex agent remains responsible for:

1. understanding scope and acceptance criteria;
2. decomposing work into exclusive ownership boundaries;
3. routing and launching subagents within available concurrency;
4. coordinating corrections and dependencies;
5. reviewing and integrating every result;
6. running integration-level verification; and
7. reporting the outcome and, when authorized and writable, writing `.codex-swarm/logs/<ISO-timestamp>.md`.

Subagents perform the substantive code, test, documentation, and content writing.

## Model routing

Routing is automatic. The skill never asks the user to select a model.

| Work profile | Exact model override | Exact reasoning effort |
|---|---|---|
| Reasoning-heavy, ambiguous, risky, architecture, debugging, tricky refactors, integration-sensitive work | `gpt-5.6-sol` | `medium` |
| Easy, isolated, boilerplate, mechanical, documentation, straightforward tests, bulk work | `gpt-5.6-luna` | `max` |

These pairs are intentional. In particular, easy work still uses `reasoning_effort: max` with `gpt-5.6-luna`.

## Installation

Clone or download this repository, then copy the skill folder to one of the directories below.

### Portable Codex-compatible location

Use `~/.agents/skills/` when you want a portable location recognized by Codex and compatible agent harnesses:

```bash
mkdir -p ~/.agents/skills
cp -R skills/codex-swarm ~/.agents/skills/codex-swarm
```

### Codex-specific location

Alternatively, install directly into Codex's skill directory:

```bash
mkdir -p ~/.codex/skills
cp -R skills/codex-swarm ~/.codex/skills/codex-swarm
```

Restart or open a fresh Codex task after installation so the skill catalog refreshes. The host harness must expose Codex collaboration/subagent tools and model overrides for the full workflow.

This repository targets Codex and Codex-compatible agent harnesses. It does not claim that the ChatGPT consumer UI can load arbitrary local skills.

## Usage

Invoke the skill explicitly:

```text
Use $codex-swarm to add an authenticated API, tests, and setup documentation.
```

```text
Use $codex-swarm to fan out migration of the independent modules under src/legacy/.
```

```text
Use $codex-swarm to delegate this substantial single-file parser refactor to one subagent.
```

It also triggers implicitly before writing or editing code, tests, docs, or other content that spans more than one file or roughly 20 lines, and when a user explicitly asks to swarm, fan out, parallelize, delegate, or use Codex/ChatGPT subagents. Merely asking about ChatGPT or Codex does not trigger the skill. Trivial one-file edits and read-only answers can remain local.

## Behavior

Each subtask receives a self-contained prompt with exact readable context, exclusive writable paths, requirements, acceptance criteria, and verification commands. Spawns with model/effort overrides explicitly use `fork_turns: "none"` (preferred) or a positive bounded turn count; full-history forks are incompatible with overrides. Independent tasks launch immediately up to the current concurrency limit; as agents finish, the host refills available slots. Shared and integration-sensitive files remain with the host or one explicit owner. Each `wait_agent` call is capped at 60 seconds, with a user update before any additional wait.

If work fails, the host inspects concrete evidence and sends a focused follow-up to the same agent when practical. It reassigns only the affected task when needed and does not silently rewrite all delegated output locally. If a required model is unavailable, the host performs one availability/error check, marks the subtask blocked, and asks for explicit fallback authorization; it never loops or silently substitutes. Completion reports include changed files, verification, assumptions, blockers, and a concise result.

The host reviews the actual artifacts and runs integration-level checks before claiming success. Agent reports and run logs support that review; neither replaces it.

## Audit logs

When project writes are authorized and the path is writable, every run writes:

```text
.codex-swarm/logs/<ISO-timestamp>.md
```

The log records the overall summary and wall-clock duration, integration verification, and—for every subtask—the model, reasoning effort, status, files, verification, and result. Failed or reassigned attempts remain visible. `.codex-swarm/` is ignored by this repository by default so project-local audit trails do not enter version control accidentally.

For read-only requests, path-restricted tasks, or unwritable projects, the host makes no unauthorized log write. It reports persistence as blocked and includes the compact audit in its final response instead.

## Repository layout

```text
codex-swarm/
├── .gitignore
├── LICENSE
├── README.md
└── skills/
    └── codex-swarm/
        ├── SKILL.md
        └── agents/
            └── openai.yaml
```

## License

[MIT](LICENSE) © 2026 Nathan ([Vallykrie](https://github.com/Vallykrie)).
