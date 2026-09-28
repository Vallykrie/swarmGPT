---
name: codex-imagegen
description: Use when the user asks to generate, create, draw, edit, or restyle an image, or when a task needs image assets — logos, icons, illustrations, hero images, textures, photos, placeholder art, social/OG cards. Most coding agents cannot produce raster images; a Codex session via the `codex` CLI has a built-in imagegen tool that can. Trigger words include "generate an image", "make a picture/logo/icon", "draw", "image asset", or /codex-imagegen.
---

# codex-imagegen

You cannot produce raster images. `codex exec` sessions can: the Codex CLI
exposes a built-in `image_gen.imagegen` tool that generates and edits images
using the user's existing ChatGPT authentication. **No API key is required**
and no `OPENAI_API_KEY` is used — this runs on the plan the user already
signed into with `codex login`.

Your job: turn the request into a precise image prompt, dispatch it, verify
the file that comes back, and deliver it.

## Step 0 — Preflight

1. `command -v codex` — if missing, stop and tell the user to install the
   Codex CLI (`npm install -g @openai/codex`) and run `codex login`.
2. Locate `dispatch.sh` as in codex-swarm Step 0. You can also call
   `codex exec` directly for a single image; the dispatcher is for batches.

## Step 1 — Build the manifest

For each requested image, record as separate fields:

- **purpose** — what it is for (icon, hero, texture, OG card…)
- **prompt** — the detailed description you will send
- **new or edit** — edits need exact input paths
- **destination** — an **absolute** output path
- **format** — png, jpg, webp

Treat a user-specified path and format as immutable. Do not rename the file,
change its extension, or pick a different directory without asking. If the
user gave no path, choose a sensible project location (`assets/`, `public/`,
`docs/images/`) and say which one you picked. If the exact path already exists
and replacement was not requested, ask before overwriting.

## Step 2 — Write the image prompt

Codex generates what you describe, so describe it fully. Cover: subject,
composition and framing, style (flat vector, 3D render, photo, watercolor…),
palette, lighting, background (state explicitly if it must be transparent),
aspect ratio, and any text that must appear verbatim. Name what must **not**
be there too — stray text, watermarks, borders.

For an **edit**, pass the exact absolute path of every input file and state
what must stay unchanged.

## Step 3 — Dispatch

One job per image. Images are independent, so a batch goes out in parallel.

Single image, directly:

```bash
codex exec "Generate an image: <full prompt>. Save it to <ABS PATH>. \
Then print a line starting with TOUCHED: listing the file." \
  --model gpt-6-luna -c model_reasoning_effort="max" \
  --sandbox workspace-write --skip-git-repo-check --cd "$PWD"
```

Batch — one `MODEL:`-headed prompt file per image, then:

```bash
bash "$DISPATCH" --auto --timeout 20m 01-icon-light.prompt.md 02-icon-dark.prompt.md
```

Every prompt must end with: "Save it to `<absolute path>`, then print a line
starting with `TOUCHED:` listing the file."

Rules:

- **The sandbox must be `workspace-write`** (`--auto`), and the destination
  must be inside the project — a read-only sandbox cannot save the file.
- One generation call per asset or variant. A retry is a **new** variant with
  its own path, never a second write to the same path.
- Two parallel jobs must never target the same output path.
- Use `gpt-6-luna` at `max` (the light tier); the image model does the
  heavy lifting, not the reasoning model.
- Image generation takes ~40–90 seconds per asset. Allow at least 5 minutes
  per job and tell the user it is running.

## Step 4 — Verify before you deliver

1. Confirm the file exists at the exact manifest path and is non-trivial in
   size (`ls -l`; a few hundred bytes means it failed).
2. **View it** with your image-reading tool. Check it against the requested
   subject, composition, text, and — for edits — that the invariants held.
3. Validate the real format from file contents, not the extension
   (`file <path>`).
4. If it is wrong, add one targeted variant to the manifest with a corrected
   prompt and its own path, dispatch that one job, and inspect again.

Report every final path, the validated format, and what you verified.

## Blocking

If `codex` is missing, unauthenticated, or the job returns no file, stop.
State which assets are incomplete and why. Do not describe an image you did
not generate, do not claim a file exists without checking, and never ask the
user to paste a secret into chat.
