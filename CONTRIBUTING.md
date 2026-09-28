# Contributing to SwarmGPT

Thanks for helping out. SwarmGPT is small on purpose: two Markdown playbooks
and one shell script, wrapped for several agent harnesses. Keeping it that way
is the main review criterion.

## Where things live

| Change | Edit |
|---|---|
| Orchestration behavior, decomposition rules, model routing | `skills/codex-swarm/SKILL.md` |
| Image generation behavior | `skills/codex-imagegen/SKILL.md` |
| Tier → model mapping | `scripts/routing.conf` **and** its copy in `skills/codex-swarm/scripts/` |
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
bash -n scripts/dispatch.sh
```

```bash
shellcheck scripts/dispatch.sh
```

```bash
cmp scripts/dispatch.sh skills/codex-swarm/scripts/dispatch.sh && cmp scripts/routing.conf skills/codex-swarm/scripts/routing.conf
```

For dispatcher changes, also do a real smoke run with two tiny prompt files
and include the status table in the PR description.

## Changing model routing

`scripts/routing.conf` is the single source of truth, and it is **live**:
every install fetches it from `main` within a day. That makes it the most
sensitive file in the repo — a bad slug breaks every user's next run.

1. Smoke-test the new models first with a literal header
   (`MODEL: <slug>`) against a real `codex exec`.
2. Raise `min-codex` if the new models need a newer CLI.
3. Update both copies of `routing.conf` and the README model table (CI
   checks both).
4. Skills name tiers only; do not put model slugs in `SKILL.md` files.

## Pull requests

- Keep PRs focused; one behavior change per PR.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for
  messages (`feat:`, `fix:`, `docs:`, `chore:`).
- Add an entry under **Unreleased** in `CHANGELOG.md`.
- Do **not** add `version` to `.claude-plugin/plugin.json`: without it,
  Claude Code users with auto-update receive every commit (CI enforces this).
  Bump `.codex-plugin/plugin.json` and `CHANGELOG.md` when cutting a release.
