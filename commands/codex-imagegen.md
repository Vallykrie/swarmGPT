---
description: Generate or edit an image via a Codex (codex exec) session — Codex's built-in imagegen tool does what your agent cannot
argument-hint: [image description...]
---

Run the **codex-imagegen** skill (`skills/codex-imagegen/SKILL.md` in this
plugin — read it now and follow it exactly).

Arguments given: `$ARGUMENTS`

Treat the whole argument string as the image request. If it is empty, ask the
user what image they want and where to save it, then proceed.

Follow the skill: build a detailed image prompt, pick an absolute output path
(ask only if no sensible default exists in the project), dispatch the codex
job with `--sandbox workspace-write`, verify by viewing the resulting file and
checking its real format, then deliver it. Multiple requested images are
dispatched in parallel, one codex job each, with distinct output paths.
