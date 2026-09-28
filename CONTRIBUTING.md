# Contributing to SwarmGPT

Thanks for helping out. SwarmGPT is small on purpose: two Markdown playbooks
and one shell script, wrapped for several agent harnesses. Keeping it that way
is the main review criterion.

## Where things live

| Change | Edit |
|---|---|
| Orchestration behavior, decomposition rules, model routing | `skills/codex-swarm/SKILL.md` |
| Image generation behavior | `skills/codex-imagegen/SKILL.md` |
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
cmp scripts/dispatch.sh skills/codex-swarm/scripts/dispatch.sh
```

For dispatcher changes, also do a real smoke run with two tiny prompt files
and include the status table in the PR description.

## Changing model routing

The routing table in `skills/codex-swarm/SKILL.md` (Step 3) is the source of
truth. When the model lineup changes, update it together with:

- the README **Model routing** table and examples,
- the example header in `scripts/dispatch.sh` (both copies),
- `skills/codex-imagegen/SKILL.md`,
- manifest descriptions and keywords,
- the stale-slug pattern in `.github/workflows/ci.yml`.

## Pull requests

- Keep PRs focused; one behavior change per PR.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for
  messages (`feat:`, `fix:`, `docs:`, `chore:`).
- Add an entry under **Unreleased** in `CHANGELOG.md`.
- Bump `version` in both `.claude-plugin/plugin.json` and
  `.codex-plugin/plugin.json` only when cutting a release.
