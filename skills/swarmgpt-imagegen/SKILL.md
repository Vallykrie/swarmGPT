---
name: swarmgpt-imagegen
description: Use when the user explicitly invokes $swarmgpt-imagegen to generate, edit, or coordinate a batch of raster image assets with the native image-generation capability.
---

# SwarmGPT ImageGen

Coordinate image work while delegating image creation and editing to the built-in `$imagegen` skill and tool. Treat the installed `$imagegen` instructions as authoritative; do not reproduce its reference, infer unsupported controls, or invent tool arguments.

## Workflow

1. Confirm that the user explicitly invoked `$swarmgpt-imagegen` and that the built-in `$imagegen` capability is available. Load and follow `$imagegen` before making image-generation calls.
2. Turn the request into an asset manifest. For each deliverable, record its purpose, prompt, constraints, whether it is new or an edit, and its intended final path or preview-only status.
3. Use the built-in path by default. Delegate transparent-background requests and all generation/edit execution details to `$imagegen`; do not substitute a custom API or CLI workflow.
4. For a new image, call the built-in capability without references.
5. For an edit with local image inputs, resolve every exact local path and inspect every input first with the available local image viewer. Give `$imagegen` those exact paths as references, label each input's role, preserve the user's invariants, and use non-destructive output naming unless replacement was explicitly requested.
6. Execute the manifest with bounded parallelism. Give every asset one owner and an exclusive final output path before starting. Never let parallel calls write, move, or copy to the same path. Use no more concurrent calls than the host supports, and reduce concurrency for dependent edits or resource pressure; run dependent work sequentially.
7. Inspect every generated or edited output visually. Check it against the requested subject, composition, text, constraints, and edit invariants. Retry only with a targeted correction, then inspect again.
8. Place project-bound finals at their assigned workspace paths according to `$imagegen` save-path guidance. Keep preview-only outputs where the built-in workflow permits.
9. Report every final artifact path, its manifest item, whether it passed inspection, and whether the built-in path or an explicitly authorized fallback produced it. Do not report an artifact as complete until it exists and has been inspected.

## Blocking and fallback

- If the built-in `$imagegen` capability is missing or unavailable, stop before promising or fabricating outputs. State which capability is unavailable and which manifest items remain incomplete.
- Mention a fallback only when the installed `$imagegen` instructions define one. Explain its requirements and behavior, including any `OPENAI_API_KEY` requirement, and proceed only after the user explicitly authorizes it.
- Do not claim that image generation is API-key-free except when the included host actually provides the built-in capability. Never ask the user to paste a secret into chat.
- If the user declines the fallback or its requirements are unmet, return a clean blocked result with the prepared manifest and no claim of generated artifacts.
