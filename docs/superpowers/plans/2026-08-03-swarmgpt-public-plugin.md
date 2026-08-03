# SwarmGPT Public Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package SwarmGPT as a public installable skills-only plugin with Codex swarm and image-generation workflows.

**Architecture:** Keep the plugin at the repository root with `.codex-plugin/plugin.json` pointing to `./skills/`. Expose the GitHub repository through `.agents/plugins/marketplace.json` as a Git-backed root plugin source, then bundle `codex-swarm` and `swarmgpt-imagegen` without an MCP server.

**Tech Stack:** Markdown agent skills, JSON plugin/marketplace manifests, YAML skill UI metadata, native Codex collaboration tools, native `$imagegen` capability, GitHub CLI.

## Global Constraints

- Keep the plugin at the repository root and point `skills` to `./skills/`.
- Use only current plugin, marketplace, skill, and invocation schemas documented by OpenAI.
- Do not add MCP, app, hook, or asset manifest paths because those components are not shipped.
- Preserve `gpt-5.6-sol` with `medium` effort and `gpt-5.6-luna` with `max` effort exactly.
- Use `$codex-swarm`, `$swarmgpt-imagegen`, `/skills`, and `/plugins`; do not create or advertise `/swarmGPT`.
- Do not require a paid API key; image generation depends on native host availability and workspace limits.
- Use `apply_patch` for repository edits and keep unrelated user changes intact.

---

### Task 1: RED Baseline Evaluations
- [ ] Launch a fresh-context, read-only subagent with `spawn_agent(fork_turns: "none")` to verify `$swarmgpt-imagegen` is not recognized.
- [ ] Launch a fresh-context subagent to attempt installing `Vallykrie/swarmGPT` as a plugin via marketplace. It should fail since the manifest is missing.
- [ ] Capture the exact failure patterns (e.g. command errors, "not found" responses) directly into the execution notes or run log of the task orchestrator.
- [ ] Do not commit these failure logs to the repository (no extra narrative file).

### Task 2: Plugin Scaffold and Manifest
- **Files:** Create `.codex-plugin/plugin.json`; use a disposable scaffold under `/private/tmp` only as the schema seed.
- **Produces:** Plugin identity `swarmgpt@0.1.0` and the `./skills/` component path consumed by marketplace and install tests.
- [ ] Create a disposable parent with `mktemp -d`, confirm it is non-empty and under `/private/tmp` or `/tmp`, then run `/Users/nathan/miniconda3/bin/python3 /Users/nathan/.codex/skills/.system/plugin-creator/scripts/create_basic_plugin.py swarmgpt --path <validated-temp-parent> --with-skills`.
- [ ] Inspect the generated manifest, then create the repository-root `.codex-plugin/plugin.json` with `apply_patch`.
- [ ] Create `.codex-plugin/plugin.json` with exactly these contents:
  ```json
  {
    "name": "swarmgpt",
    "version": "0.1.0",
    "description": "Multi-agent orchestration and image generation workflows for ChatGPT and Codex.",
    "author": {
      "name": "Nathan",
      "email": "nathansudiara@gmail.com",
      "url": "https://github.com/Vallykrie"
    },
    "homepage": "https://github.com/Vallykrie/swarmGPT",
    "repository": "https://github.com/Vallykrie/swarmGPT.git",
    "license": "MIT",
    "keywords": ["chatgpt", "codex", "openai", "multi-agent", "subagents", "agent-skills", "image-generation", "ai-agents"],
    "skills": "./skills/",
    "interface": {
      "displayName": "SwarmGPT",
      "shortDescription": "Orchestrate agents and image generation",
      "longDescription": "Route substantial work across Codex subagents and coordinate native image generation with focused, verifiable workflows.",
      "developerName": "Vallykrie",
      "category": "Developer Tools",
      "capabilities": ["Read", "Write"],
      "websiteURL": "https://github.com/Vallykrie/swarmGPT",
      "defaultPrompt": [
        "Use Codex Swarm to parallelize this task.",
        "Generate these image assets with SwarmGPT."
      ],
      "brandColor": "#10A37F"
    }
  }
  ```
- [ ] Verify the manifest has no apps/MCP/hooks/assets paths.
- [ ] Validate the manifest: `/Users/nathan/miniconda3/bin/python3 /Users/nathan/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .`; expected output identifies the plugin as valid.
- [ ] Commit checkpoint: `git add .codex-plugin/plugin.json && git commit -m "feat: add root plugin manifest"`

### Task 3: Repo Marketplace Entry
- **Files:** Create `.agents/plugins/marketplace.json`.
- **Consumes:** Root plugin identity `swarmgpt`; **Produces:** marketplace `swarmgpt` with a Git-backed root source.
- [ ] Create `.agents/plugins/marketplace.json` with exactly these contents:
  ```json
  {
    "name": "swarmgpt",
    "interface": {
      "displayName": "SwarmGPT"
    },
    "plugins": [
      {
        "name": "swarmgpt",
        "source": {
          "source": "url",
          "url": "https://github.com/Vallykrie/swarmGPT.git",
          "ref": "main"
        },
        "policy": {
          "installation": "AVAILABLE",
          "authentication": "ON_INSTALL"
        },
        "category": "Developer Tools"
      }
    ]
  }
  ```
- [ ] Validate syntax with `jq empty .agents/plugins/marketplace.json`, assert `.plugins[0].source.source == "url"`, and confirm no `path` is present because the Git URL resolves to the repository-root plugin.
- [ ] Commit checkpoint: `git add .agents/plugins/marketplace.json && git commit -m "feat: add marketplace entry"`

### Task 4: New `swarmgpt-imagegen` Skill
- **Files:** Create `skills/swarmgpt-imagegen/SKILL.md` and `skills/swarmgpt-imagegen/agents/openai.yaml`.
- **Consumes:** Native `$imagegen`; **Produces:** focused `$swarmgpt-imagegen` orchestration workflow.
- [ ] Initialize with `/Users/nathan/miniconda3/bin/python3 /Users/nathan/.codex/skills/.system/skill-creator/scripts/init_skill.py swarmgpt-imagegen --path skills --interface 'display_name=SwarmGPT ImageGen' --interface 'short_description=Coordinate native image generation batches' --interface 'default_prompt=Use $swarmgpt-imagegen to generate or edit these image assets.'`.
- [ ] Replace the generated skill template and confirm `agents/openai.yaml` contains:
  ```yaml
  interface:
    display_name: "SwarmGPT ImageGen"
    short_description: "Coordinate native image generation batches"
    default_prompt: "Use $swarmgpt-imagegen to generate or edit these image assets."
  ```
- [ ] Implement `skills/swarmgpt-imagegen/SKILL.md`:
  - Explicit invocation via `$swarmgpt-imagegen`.
  - Required underlying capability is the built-in `$imagegen` tool.
  - For new images: omit references.
  - For edits: inspect local inputs first and use exact reference paths.
  - Batching: exclusive output paths and bounded parallelism.
  - Output handling: inspect every output and report artifacts.
  - Fallbacks: block cleanly when image generation is unavailable. Do not claim API-key-free support beyond included host availability.
- [ ] Run `/Users/nathan/miniconda3/bin/python3 /Users/nathan/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/swarmgpt-imagegen`; expected `Skill is valid!`.
- [ ] Run forward tests in a fresh subagent to confirm basic loading.
- [ ] Commit checkpoint: `git add skills/swarmgpt-imagegen && git commit -m "feat: add swarmgpt-imagegen skill"`

### Task 5: Existing `codex-swarm` Metadata Refinement
- [ ] Inspect `skills/codex-swarm/SKILL.md` to ensure exact `gpt-5.6-sol`/`medium` and `gpt-5.6-luna`/`max` routing remains unchanged.
- [ ] Ensure plugin invocation terminology and public visibility are accurate.
- [ ] Regenerate/validate `skills/codex-swarm/agents/openai.yaml` if modifications were made.
- [ ] Commit checkpoint (if changed): `git add skills/codex-swarm && git commit -m "chore: refine codex-swarm metadata for public plugin"`

### Task 6: Rewrite Root README
- **Files:** Modify `README.md`.
- **Consumes:** Final manifest, marketplace, and both skill names; **Produces:** public onboarding and SEO copy.
- [ ] Update `README.md` title and opening paragraph for public SEO without keyword stuffing.
- [ ] Add only badges that resolve without unshipped infrastructure: MIT license, plugin version `0.1.0`, and ChatGPT/Codex compatibility. Do not add a CI/build badge without a workflow.
- [ ] Add a feature table summarizing `codex-swarm` and `swarmgpt-imagegen`.
- [ ] Explain "Why/What" of the plugin.
- [ ] Add an Install section with exact commands: `codex plugin marketplace add Vallykrie/swarmGPT`, then document the install/browse flow.
- [ ] Add Invocation instructions: `/plugins`, `/skills`, `$codex-swarm`, `$swarmgpt-imagegen`, supported `@swarmGPT` ChatGPT mentions.
- [ ] Include Model Routing explaining `gpt-5.6-sol`/`medium` and `gpt-5.6-luna`/`max`.
- [ ] Add an Image Generation section detailing the native, parallel workflow.
- [ ] Add an Architecture section explaining native subagents/tools (no MCP server).
- [ ] Provide concrete examples and a compatibility matrix.
- [ ] Add Troubleshooting/FAQ (explicitly explaining why there is no `/swarmGPT` command).
- [ ] Add contributing, license, repository tree, and keywords. Link only to real official OpenAI docs and repository paths.
- [ ] Ensure a fresh session requirement is documented in the README after installation.
- [ ] Commit checkpoint: `git add README.md && git commit -m "docs: rewrite README for public SEO and onboarding"`

### Task 7: Repo Hygiene
- [ ] Update `.gitignore` to explicitly ignore `.gemini-swarm/` and `.codex-swarm/`.
- [ ] Run JSON/YAML linters on all manifest and metadata files.
- [ ] Run `grep -r "/swarmGPT" .` to scan for and remove deprecated slash-command claims or placeholders.
- [ ] Run `git diff --check` to ensure no whitespace errors. Ensure `git status` is clean.
- [ ] Commit checkpoint: `git add .gitignore && git commit -m "chore: repository hygiene and gitignore updates"`

### Task 8: GREEN/REFACTOR Forward Tests
- [ ] Launch fresh-context agents to exercise activation and non-activation of skills.
- [ ] Verify exact routing triggers properly in simulated contexts.
- [ ] Verify image batch ownership, inspection, and error handling for `swarmgpt-imagegen`.
- [ ] Verify unsupported tool behavior triggers cleanly.
- [ ] Verify install/invocation explanations align with the new README.
- [ ] Address any findings and re-run validators.
- [ ] Commit checkpoint (if changes made): `git commit -am "test: address forward test findings"`

### Task 9: Local Install Smoke Test
- [ ] Add the marketplace with `codex plugin marketplace add Vallykrie/swarmGPT` if it is not already configured.
- [ ] Inspect presence using `codex plugin marketplace list` and `codex plugin list`.
- [ ] Attempt installation via `codex plugin add swarmgpt@swarmgpt`.
- [ ] Document any surface limitations without claiming success if blocked by host constraints.

### Task 10: GitHub Public Metadata and Release
- [ ] Use `gh repo edit Vallykrie/swarmGPT` with description `Installable ChatGPT and Codex plugin for multi-agent orchestration and native image generation.` and homepage `https://github.com/Vallykrie/swarmGPT`.
- [ ] Add the focused topics `chatgpt`, `codex`, `openai`, `multi-agent`, `subagents`, `agent-skills`, `codex-plugin`, `image-generation`, `developer-tools`, and `ai-agents` using the current `gh repo edit --add-topic` syntax shown by `gh repo edit --help`.
- [ ] Push local commits: `git push origin main`.
- [ ] Verify remote commit and repo metadata reflect changes.
- [ ] Do NOT create a GitHub release unless explicitly requested.
