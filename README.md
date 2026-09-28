# SwarmGPT

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/Version-0.4.0-blue.svg)](CHANGELOG.md)
[![CI](https://github.com/Vallykrie/swarmGPT/actions/workflows/ci.yml/badge.svg)](https://github.com/Vallykrie/swarmGPT/actions/workflows/ci.yml)
[![Codex CLI](https://img.shields.io/badge/Codex%20CLI-%E2%89%A50.158.0-black.svg)](https://developers.openai.com/codex/cli)
[![Models](https://img.shields.io/badge/Models-GPT--6%20Astra%20%C2%B7%20Sol%20%C2%B7%20Luna-10A37F.svg)](#model-routing)

**Make Codex your writer.** Your coding agent plans, routes, and reviews;
parallel `codex exec` sessions do the token-heavy writing on the ChatGPT plan
you already pay for. Plus real image generation — Codex has a built-in
`imagegen` tool, so your agent can finally produce actual PNGs.

Sibling project: [gemini-swarm-skill](https://github.com/Vallykrie/gemini-swarm-skill),
the same idea pointed at Gemini via the Antigravity CLI.

---

## Why

You are paying for ChatGPT Plus/Pro and barely touching it, because your daily
driver is Claude Code (or Cursor, or OpenCode). Meanwhile your orchestrator
burns context writing boilerplate it could have delegated.

SwarmGPT flips that:

- **Your agent orchestrates.** Decomposition, routing, review, integration,
  verification — the judgment work stays where the conversation is.
- **Codex writes.** Each subtask becomes its own `codex exec` session with its
  own file ownership. They all launch at once.
- **Raw output never enters your context.** The dispatcher writes full
  transcripts to disk and returns a status table plus each session's final
  message.
- **Images actually get generated.** `codex exec` exposes
  `image_gen.imagegen`, authenticated by your ChatGPT login. No API key.

Good fit: test suites across independent files, porting modules, scaffolding,
mass refactors, docstrings at scale, multi-topic research, batches of image
assets. Poor fit: one big file with interdependent changes, or strictly
sequential steps.

---

## What's in the box

| Component | What it does |
|---|---|
| `codex-swarm` skill | The playbook: delegate-by-default rule, decomposition, model routing, dispatch, review, run log. |
| `codex-imagegen` skill | Image generation and editing through Codex's built-in imagegen tool. |
| `/codex-swarm` command | Explicit invocation with a sandbox mode. |
| `/codex-imagegen` command | Explicit image request. |
| `codex-dispatcher` subagent | Runs the script, waits, writes the run log, returns a small summary. Keeps Codex output out of your main context. |
| `scripts/dispatch.sh` | Harness-independent parallel runner. Any agent that can run Bash can use it. |

---

## Install

### Step 1 — Install the Codex CLI

```bash
npm install -g @openai/codex
```

Or with Homebrew:

```bash
brew install codex
```

Verify — the GPT-6 models need **0.158.0 or newer** (`npm install -g @openai/codex@latest` to upgrade):

```bash
codex --version
```

### Step 2 — Log in

```bash
codex login
```

Pick **Sign in with ChatGPT** and complete the browser flow. This is what makes
both the swarm and the image generation free of API keys — they run on your
ChatGPT plan's included usage. (`codex login --api-key` also works if you would
rather bill the API.)

Confirm it works:

```bash
codex exec "reply with OK and nothing else" --sandbox read-only --skip-git-repo-check
```

### Step 3 — Install the plugin in Claude Code

Run these as **two separate commands** inside Claude Code:

```
/plugin marketplace add Vallykrie/swarmGPT
```

```
/plugin install swarmgpt@swarmgpt
```

Then confirm: `/help` should list `/codex-swarm` and `/codex-imagegen`.

### Step 4 — Turn on auto-update (recommended)

Claude Code leaves auto-update off for third-party marketplaces. Turn it on
once so skill and dispatcher fixes reach you automatically: open `/plugin`,
go to **Marketplaces**, select **swarmgpt**, and choose **Enable
auto-update**. Without it, update manually with
`/plugin marketplace update swarmgpt`.

Model routing does not depend on this step — see
[Always-current routing](#always-current-routing).

Using a different harness? See [docs/harnesses.md](docs/harnesses.md) for
Cursor, OpenCode, Gemini CLI / Antigravity, and the generic adapter — the
skill and the script are harness-independent.

---

## Use it

Once installed, the `codex-swarm` skill fires **automatically** whenever a task
involves writing across more than one file or more than ~20 lines. You do not
need the slash command. Use it when you want to force a specific sandbox mode:

```
/codex-swarm auto Port every module under src/legacy/ to TypeScript and write a migration report.
```

```
/codex-imagegen A flat-design app icon, indigo on white, rounded square, save to assets/icon.png
```

### Sandbox modes

| Mode | Codex flag | Codex jobs may |
|---|---|---|
| `default` | mirrors your host | auto-accept host → `auto`; review-mode host → `readonly` |
| `auto` | `--sandbox workspace-write` | write anywhere in the project, no network |
| `readonly` | `--sandbox read-only` | read and analyze only; reports back |
| `yolo` | `--dangerously-bypass-approvals-and-sandbox` | anything — only in a container/VM |

`codex exec` is non-interactive, so there is no TTY to approve a gated command.
That is why the modes are sandbox levels rather than approval policies.

### Model routing

Automatic, per subtask — you are never asked to pick. Each subtask is
classified by its hardest requirement; ties go to the heavier tier.

| Tier | Work profile | Model (current) | Effort |
|---|---|---|---|
| `heavy` | Architecture, cross-cutting refactors, gnarly debugging, concurrency- or security-sensitive code | `gpt-6-astra` | `low` |
| `medium` | Feature work with real logic, non-trivial refactors, integration-sensitive changes, investigative bug fixes | `gpt-6-sol` | `medium` |
| `light` | Scaffolding, renames, format conversions, test scaffolding, docs, straightforward CRUD, image jobs | `gpt-6-luna` | `max` |

### Always-current routing

The skill only ever names a **tier**. `dispatch.sh` maps tiers to concrete
models through [`scripts/routing.conf`](scripts/routing.conf), and refreshes
that table from this repository's `main` branch at most once a day
(cached in `~/.cache/swarmgpt/`). When OpenAI ships or retires a model, one
edit to `routing.conf` re-routes every install — Claude Code, Cursor,
OpenCode, a stale git clone — without anyone updating the plugin.

- **Offline or GitHub unreachable?** It uses the last cached table, then the
  copy bundled with your install. A fetch failure never blocks a run.
- **Locked-down by design.** A fetched table may only contain tier, model and
  effort names plus a minimum CLI version; anything else rejects the whole
  file. It cannot run commands.
- **Too-old CLI?** The table carries `min-codex`, and dispatch stops with
  upgrade instructions instead of failing every job.

```bash
bash scripts/dispatch.sh --print-routing
```

| Variable | Effect |
|---|---|
| `SWARMGPT_OFFLINE=1` | never fetch; use the cache or the bundled table |
| `SWARMGPT_ROUTING=/path/file` | pin your own routing table (no fetch) |
| `SWARMGPT_ROUTING_URL` | fetch from a fork or internal mirror instead |
| `SWARMGPT_ROUTING_TTL` | seconds between fetch attempts (default `86400`) |

---

## Under the hood

Each subtask becomes a prompt file whose first line names its tier:

```
MODEL: light

Goal: ...
Own: src/parser/tokens.ts
...
When done, print a line starting with TOUCHED: listing every file you
created or modified, then a one-paragraph summary.
```

The dispatcher launches them all concurrently and blocks until every job ends:

```bash
bash scripts/dispatch.sh --auto --timeout 20m 01-*.prompt.md 02-*.prompt.md
```

```
dispatched: 01-schema   [heavy -> gpt-6-astra/low]  (pid 85779)
dispatched: 02-handler  [medium -> gpt-6-sol/medium]  (pid 85798)
dispatched: 03-docs     [light -> gpt-6-luna/max]  (pid 85811)
routing: remote, cached from https://raw.githubusercontent.com/Vallykrie/swarmGPT/main/scripts/routing.conf
waiting on 3 parallel codex job(s), 1200s cap each...

run directory: .codex-swarm/logs/2026-09-28T01-19-20Z
SUBTASK      MODEL          EFFORT   STATUS SECONDS
01-schema    gpt-6-astra    low      ok     94
02-handler   gpt-6-sol      medium   ok     61
03-docs      gpt-6-luna     max      ok     38
```

Artifacts land in `.codex-swarm/logs/<timestamp>/`:

| File | Contents |
|---|---|
| `<name>.last` | just the agent's final message — safe to read whole |
| `<name>.out` | full event stream — **never** read this into an agent's context |
| `<name>.err` | stderr; the first place to look on `FAIL` |
| `results.tsv` | `name · model · effort · exit_code · seconds` |

Plus a human-readable `.codex-swarm/logs/<timestamp>.md` run log. Add
`.codex-swarm/` to your `.gitignore`.

Script options: `--auto` / `--readonly` / `--yolo`, `--timeout 20m`,
`--jobs N` (concurrency cap, default unlimited), `--log-root DIR`,
`--print-routing`.
Exit code is 0 only if every job succeeded.

---

## Repository layout

```text
.
├── .claude-plugin/          # Claude Code plugin + marketplace manifests
├── .codex-plugin/           # optional: Codex CLI plugin manifest
├── .agents/plugins/         # optional: Codex marketplace snapshot
├── agents/
│   └── codex-dispatcher.md
├── commands/
│   ├── codex-swarm.md
│   └── codex-imagegen.md
├── scripts/
│   ├── dispatch.sh
│   └── routing.conf         # tier → model table, fetched live by every install
├── skills/
│   ├── codex-swarm/
│   │   ├── SKILL.md
│   │   └── scripts/              # byte-identical copies for standalone installs (CI-enforced)
│   └── codex-imagegen/SKILL.md
├── docs/harnesses.md
└── .github/                 # CI, issue and PR templates
```

---

## Optional: installing into Codex itself

An interactive Codex session **does not need this plugin's dispatcher** — Codex
ships native multi-agent support (`spawn_agent`/`wait_agent`) and its own
`imagegen` tool. Use those directly instead.

If you still want the per-subtask routing and on-disk run logs from inside
Codex, the repo carries a Codex plugin manifest:

```bash
codex plugin marketplace add https://github.com/Vallykrie/swarmGPT
codex plugin add swarmgpt
```

Or install the playbook as a prompt — see
[docs/harnesses.md](docs/harnesses.md).

---

## Troubleshooting

**`dispatch.sh: 'codex' not found on PATH`** — Step 1 did not finish, or your
shell has not picked up the npm global bin directory. Check with
`which codex`.

**`codex … is too old; the routed models need …`** (or Codex's own
"requires a newer version of Codex") — the `codex` first on your `PATH` is
older than the routing table's `min-codex`. Upgrade, then check
`which -a codex`: a stale copy earlier on `PATH` (e.g. `~/.local/bin`) wins.

**Every job fails in a couple of seconds** — almost always auth. Run
`codex login`, then retry the Step 2 smoke test.

**A job hangs until the timeout** — it hit a command that needs approval.
`codex exec` has no TTY to approve it. Re-dispatch with `--auto` so the
sandbox grants writes up front, or narrow the subtask.

**Image generation saved nothing** — the job must run with
`--sandbox workspace-write` and the destination must sit inside the project
directory. A read-only sandbox silently has nowhere to write.

**Skills don't show up in Claude Code** — run the two `/plugin` commands
separately, then start a fresh session.

**Rate limits with a big fan-out** — pass `--jobs 4` (or whatever your plan
tolerates) to cap concurrency.

---

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Behavior
lives in `skills/*/SKILL.md` and `scripts/dispatch.sh`; change it there, not in
the per-harness wrappers. Release notes are in [CHANGELOG.md](CHANGELOG.md),
and security reports go through [SECURITY.md](SECURITY.md).

## License

[MIT](./LICENSE)
