# Running SwarmGPT in other harnesses

The whole plugin is two Markdown playbooks (`skills/codex-swarm/SKILL.md`,
`skills/codex-imagegen/SKILL.md`) plus one shell script
(`scripts/dispatch.sh`). Every harness adapter below is a thin wrapper that
(a) makes the playbook load into the agent's context at the right time and
(b) makes `dispatch.sh` reachable. **Do not fork the logic** — if you change
behavior, change `SKILL.md` and let every wrapper pick it up.

The script has no harness dependencies at all: any agent that can run Bash can
use it. In all cases the requirements are the same as Claude Code's: `codex`
on `PATH`, logged in (`codex login`), project directory writable.

---

## Claude Code — the reference install

See the README. `/plugin marketplace add Vallykrie/swarmGPT` then
`/plugin install swarmgpt@swarmgpt`. You get both skills, both slash commands,
and the `codex-dispatcher` subagent that keeps raw Codex output out of your
main context.

---

## Cursor / Windsurf / any agent with a rules file

These read a project rules file rather than a plugin manifest.

```bash
git clone https://github.com/Vallykrie/swarmGPT ~/.swarmgpt
```

Then add to `.cursor/rules/swarmgpt.mdc` (or the equivalent):

```markdown
---
description: Delegate multi-file writing to parallel Codex sessions
alwaysApply: true
---
Before writing content that spans more than one file or ~20 lines, follow the
playbook at ~/.swarmgpt/skills/codex-swarm/SKILL.md. The dispatcher script is
~/.swarmgpt/scripts/dispatch.sh. For image assets, follow
~/.swarmgpt/skills/codex-imagegen/SKILL.md.
```

No subagent layer exists here, so the main agent runs `dispatch.sh` itself.
That is fine: the script keeps raw Codex output on disk and prints only a
status table, so context stays clean — just never `cat` a `.out` file.

---

## OpenCode

OpenCode supports Claude-compatible skills, custom commands, and subagents
natively.

```bash
git clone https://github.com/Vallykrie/swarmGPT /tmp/sgp
mkdir -p ~/.config/opencode/skills
cp -r /tmp/sgp/skills/codex-swarm /tmp/sgp/skills/codex-imagegen ~/.config/opencode/skills/
```

OpenCode discovers `skills/*/SKILL.md` with the same frontmatter format, and
the bundled `scripts/dispatch.sh` travels with the `codex-swarm` folder.
Project-local install: `.opencode/skills/` instead.

Optional command wrapper (`~/.config/opencode/commands/codex-swarm.md`):

```markdown
---
description: Swarm a task across parallel Codex (codex exec) sessions
---
Use the codex-swarm skill. Arguments (mode then task): $ARGUMENTS
```

Optional subagent — copy `agents/codex-dispatcher.md` into
`~/.config/opencode/agents/`, change the frontmatter `model:` to an OpenCode
model id (e.g. `anthropic/claude-haiku-4-5`) and `tools:` to OpenCode's map
format:

```yaml
mode: subagent
tools:
  bash: true
  read: true
  write: true
  edit: false
```

**Mode mapping:** permission config `"bash": "allow"` ⇒ `--auto`; `"ask"` ⇒
`--readonly`.

---

## Gemini CLI / Antigravity (agy)

Gemini orchestrating Codex is a perfectly good pairing — one plan-and-review
model, one writer pool.

```bash
git clone https://github.com/Vallykrie/swarmGPT
cd swarmGPT
agy plugin import claude     # imports the Claude plugin layout, incl. scripts/
agy plugin list
```

For plain Gemini CLI, drop a pointer in `GEMINI.md` instead:

> For writing that spans more than one file, follow the playbook in
> `~/.swarmgpt/skills/codex-swarm/SKILL.md` (dispatcher:
> `~/.swarmgpt/scripts/dispatch.sh`).

**Mode mapping:** host `always-proceed` ⇒ `--auto`; `request-review`/strict ⇒
`--readonly`.

---

## Codex CLI itself — Codex orchestrating Codex

Worth being clear about: **an interactive Codex session does not need this
plugin's dispatcher.** Codex ships native multi-agent support (`spawn_agent` /
`wait_agent`, feature flag `multi_agent`) and a built-in `imagegen` tool, so
inside the Codex TUI you should use those directly. SwarmGPT exists to give
*other* harnesses that capability.

The one case where it still helps is running a large fan-out from a Codex
session with per-subtask model routing and on-disk run logs. Install it as a
prompt:

```bash
git clone https://github.com/Vallykrie/swarmGPT ~/.swarmgpt
mkdir -p ~/.codex/prompts
{ echo '---'
  echo 'description: Swarm a task across parallel codex exec sessions'
  echo '---'
  echo 'The dispatcher script is at ~/.swarmgpt/scripts/dispatch.sh.'
  echo 'Mode/task arguments: $ARGUMENTS'
  cat ~/.swarmgpt/skills/codex-swarm/SKILL.md
} > ~/.codex/prompts/codex-swarm.md
```

Codex also has a plugin marketplace (`codex plugin marketplace add`), and this
repo carries a `.codex-plugin/plugin.json` for it — see the README's optional
section.

**Mode mapping:** host `--full-auto` ⇒ `--auto`; approval-required modes ⇒
`--readonly`.

---

## Anything else

Minimum viable adapter for any agent that can run shell commands:

1. Put `SKILL.md` where the agent reads it when the user asks to "swarm" a
   task (system prompt include, rules file, `AGENTS.md`, etc.).
2. Make sure `scripts/dispatch.sh` exists at a path mentioned alongside it.
3. Map the host's permission mode to `--auto` / `--readonly` for the skill's
   `default` mode.

That's the entire contract.
