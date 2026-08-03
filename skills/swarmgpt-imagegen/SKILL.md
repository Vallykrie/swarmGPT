---
name: swarmgpt-imagegen
description: Use when the user explicitly invokes $swarmgpt-imagegen to generate, edit, or coordinate a batch of raster image assets with the native image-generation capability.
---

# SwarmGPT ImageGen

Coordinate image work while delegating image creation and editing to the built-in `$imagegen` skill and tool. Treat the installed `$imagegen` instructions as authoritative; do not reproduce its reference, infer unsupported controls, or invent tool arguments.

## Workflow

1. Confirm that the user explicitly invoked `$swarmgpt-imagegen` and that the built-in `$imagegen` capability is available. Load and follow `$imagegen` before making image-generation calls.
2. Turn the request into an asset manifest. For each deliverable, record its purpose, prompt, constraints, whether it is new or an edit, the exact requested destination path (or preview-only status), and the requested file format as separate fields. Treat a user-requested path and format as immutable: do not rename the file, change its extension or format, or choose a different destination without explicit user authorization. If the user gave no exact destination, assign a new non-conflicting path and preserve non-destructive versioned naming. If an exact requested path already exists and replacement was not explicitly requested, stop and ask whether to overwrite it or use a different path.
3. Use the built-in path by default. Delegate transparent-background requests and all generation/edit execution details to `$imagegen`; do not substitute a custom API or CLI workflow.
4. For a new image, call the built-in capability without references.
5. For an edit with local image inputs, resolve every exact local path and inspect every input first with the available local image viewer. Give `$imagegen` those exact paths as references, label each input's role, preserve the user's invariants, and use non-destructive output naming unless replacement was explicitly requested.
6. Execute exactly one built-in image-generation call per manifest asset or variant. Parallelize only distinct calls, keep concurrency within host-supported bounds, and run dependent work sequentially. Give every asset or variant one owner and an exclusive working output path before starting; never let parallel calls write, move, or copy to the same path. Record any retry as a new targeted variant with its own single call and exclusive working path rather than calling twice for one manifest item.
7. Inspect every generated or edited output visually. Check it against the requested subject, composition, text, constraints, and edit invariants. If correction is needed, add one targeted variant to the manifest, execute its one call, and inspect it.
8. Place the selected project-bound final at the manifest's exact destination according to `$imagegen` save-path guidance and encode it in the requested file format. Do not silently change either field. Keep preview-only outputs where the built-in workflow permits.
9. Before completion, verify that every project-bound final exists at its exact manifest path and validate its actual file format from file contents or image metadata, not only its extension. Report every final artifact path, requested and validated format, manifest item, inspection result, and whether the built-in path or an explicitly authorized fallback produced it. Do not report an artifact as complete until these checks pass.

## Blocking and fallback

- If the built-in `$imagegen` capability is missing or unavailable, stop before promising or fabricating outputs. State which capability is unavailable and which manifest items remain incomplete.
- Mention a fallback only when the installed `$imagegen` instructions define one. Explain its requirements and behavior, including any `OPENAI_API_KEY` requirement, and proceed only after the user explicitly authorizes it.
- Do not claim that image generation is API-key-free except when the included host actually provides the built-in capability. Never ask the user to paste a secret into chat.
- If the user declines the fallback or its requirements are unmet, return a clean blocked result with the prepared manifest and no claim of generated artifacts.
