# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-09-28

### Added

- **Always-current model routing.** Skills now name a tier (`heavy`,
  `medium`, `light`) and `dispatch.sh` resolves it through
  `scripts/routing.conf`, refreshed from `main` at most once a day and cached
  in `~/.cache/swarmgpt/`. Model changes reach every install without a plugin
  update. Falls back to the cache, then the bundled table, when offline.
- Strict validation of fetched routing tables (tier, model and effort names
  only); `SWARMGPT_OFFLINE`, `SWARMGPT_ROUTING`, `SWARMGPT_ROUTING_URL` and
  `SWARMGPT_ROUTING_TTL` overrides; `--print-routing`.
- Pre-flight Codex CLI version check against the table's `min-codex`, with
  upgrade instructions instead of every job failing.
- Warning when a routed model is missing from the local Codex model list.
- README step for enabling Claude Code auto-update.

### Changed

- The Claude Code plugin manifest no longer pins `version`, so users with
  auto-update track every commit.
- `codex-imagegen` dispatches every image through `dispatch.sh` with the
  `light` tier.
- Literal model slugs in `MODEL:` headers still work, for explicit requests.

## [0.3.0] - 2026-09-28

### Changed

- **Model routing moves to GPT-6 with three difficulty tiers.** Subtasks are
  classified by their hardest requirement and routed automatically:
  - Heavy → `gpt-6-astra` at `low` effort
  - Medium → `gpt-6-sol` at `medium` effort
  - Light → `gpt-6-luna` at `max` effort
- Minimum Codex CLI is now **0.158.0** (required by the GPT-6 models).
- `codex-imagegen` jobs now run on the light tier (`gpt-6-luna` / `max`).
- README reorganized with a routing table, CI badge, and updated examples.

### Added

- GitHub Actions CI: ShellCheck, dispatcher-copy parity, manifest JSON
  validation, version agreement, and a stale-model-slug guard.
- `CONTRIBUTING.md`, `SECURITY.md`, issue and pull request templates,
  `.editorconfig`.

### Removed

- The `gpt-5.6-sol` / `gpt-5.6-luna` routing.

## [0.2.0] - 2026-08-04

### Added

- Harness-independent `dispatch.sh` driving parallel `codex exec` sessions.
- Adapters for Cursor, OpenCode, Gemini CLI / Antigravity, and Codex.
- `codex-imagegen` skill and `/codex-imagegen` command.
- `codex-dispatcher` subagent that keeps raw Codex output out of context.

## [0.1.0] - 2026-08-03

### Added

- Initial `codex-swarm` skill and Claude Code plugin manifests.

[Unreleased]: https://github.com/Vallykrie/swarmGPT/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/Vallykrie/swarmGPT/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Vallykrie/swarmGPT/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Vallykrie/swarmGPT/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Vallykrie/swarmGPT/releases/tag/v0.1.0
