# Security Policy

## Supported versions

Only the latest release on `main` receives fixes.

## Reporting a vulnerability

Please **do not** open a public issue. Report privately through
[GitHub Security Advisories](https://github.com/Vallykrie/swarmGPT/security/advisories/new).
You should get an acknowledgement within a few days.

## Scope notes

SwarmGPT launches `codex exec` processes on your machine. The relevant
safety boundaries are:

- **Sandbox mode.** `--auto` and `--readonly` rely on the Codex CLI sandbox.
  `--yolo` disables it entirely and is intended only for already-isolated
  environments (containers, VMs).
- **Credentials.** SwarmGPT never reads or stores credentials; authentication
  is handled by `codex login`. Do not paste `~/.codex/auth.json` or `.out`
  event streams into issues.
- **Prompt files.** Subtask prompts are executed by an autonomous agent with
  write access to the project in `--auto` mode. Treat them like code.
