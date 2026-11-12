# Contributing to SwarmGPT

Thanks for helping out. SwarmGPT is small on purpose: two Markdown playbooks
and one shell script, wrapped for several agent harnesses. Keeping it that way
is the main review criterion.

## Where things live

| Change | Edit |
|---|---|
| Orchestration behavior, decomposition rules, model routing | `skills/codex-swarm/SKILL.md` |
| Image generation behavior | `skills/codex-imagegen/SKILL.md` |
| Live model list | `scripts/list-models.sh` **and** its copy in `skills/codex-swarm/scripts/` |
| Parallel runner, flags, log layout | `scripts/dispatch.sh` **and** its copy in `skills/codex-swarm/scripts/` |
| Claude Code slash commands / subagent | `commands/`, `agents/` |
| Plugin metadata | `.claude-plugin/`, `.codex-plugin/`, `.agents/plugins/` |
| Other harnesses | `docs/harnesses.md` |

Per-harness wrappers should stay thin. If you are adding logic to a wrapper,
it probably belongs in a `SKILL.md` instead.

## Development setup

You need the [Codex CLI](https://developers.openai.com/codex/cli) logged in
(`codex login`) and [ShellCheck](https://www.shellcheck.net/).

Run the same checks as CI before opening a PR:

```bash
bash -n scripts/dispatch.sh && bash -n scripts/list-models.sh
```

```bash
shellcheck scripts/dispatch.sh scripts/list-models.sh
```

```bash
cmp scripts/dispatch.sh skills/codex-swarm/scripts/dispatch.sh && cmp scripts/list-models.sh skills/codex-swarm/scripts/list-models.sh
```

For dispatcher changes, also do a real smoke run with two tiny prompt files
and include the status table in the PR description.

## Models

There is nothing to update when OpenAI ships or retires a model. The
orchestrator reads the live list from `scripts/list-models.sh` (a wrapper
around `codex debug models`) and chooses a model and effort per subtask.
Keep model slugs out of `SKILL.md` files, the README's install steps, and the
scripts; CI rejects versioned slugs outside the CHANGELOG and README examples.
To change *how* models are chosen, edit Step 3 of
`skills/codex-swarm/SKILL.md`.

## Pull requests

- Keep PRs focused; one behavior change per PR.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for
  messages (`feat:`, `fix:`, `docs:`, `chore:`).
- Add an entry under **Unreleased** in `CHANGELOG.md`.
- Do **not** add `version` to `.claude-plugin/plugin.json`: without it,
  Claude Code users with auto-update receive every commit (CI enforces this).
  Bump `.codex-plugin/plugin.json` and `CHANGELOG.md` when cutting a release.
