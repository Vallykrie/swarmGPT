# SwarmGPT: Multi-Agent Orchestration & Native Image Generation for ChatGPT and Codex

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0-blue.svg)](.codex-plugin/plugin.json)
[![Compatibility: ChatGPT + Codex](https://img.shields.io/badge/Compatibility-ChatGPT%20%2B%20Codex-brightgreen.svg)](#compatibility-matrix)

SwarmGPT is a universal, skills-only plugin designed for ChatGPT and Codex that brings robust multi-agent orchestration and coordinated native image generation directly into your AI workspace. By leveraging native host capabilities without relying on external servers, CLI orchestrators, or third-party API keys, SwarmGPT enables developer teams to seamlessly route complex coding tasks to specialized subagents and coordinate advanced parallel image generation workflows.

---

## Feature Overview

| Skill | Codex Invocation | Primary Purpose | Key Features & Capabilities |
| :--- | :--- | :--- | :--- |
| **[`codex-swarm`](skills/codex-swarm/SKILL.md)** | `$codex-swarm`<br>(or selection via `/skills` in Codex) | Multi-agent task decomposition, parallel coding, and review. | • Automatic model routing (`gpt-5.6-sol` / `gpt-5.6-luna`) based on complexity.<br>• Parallel subagent execution with bounded turns.<br>• Integration-level verification and audit logs. |
| **[`swarmgpt-imagegen`](skills/swarmgpt-imagegen/SKILL.md)** | `$swarmgpt-imagegen`<br>(or selection via `/skills` in Codex) | Native image generation and editing coordination. | • Bounded parallel generation of multiple assets/variants.<br>• Native input inspection, reference passing, and verification.<br>• Cleanly blocks if required host tools are unavailable. |

---

## Why / What

### Why a Plugin?
Traditional custom slash prompts or custom command scripts are difficult to distribute and manage across multiple modern AI surfaces. By aligning with the universal plugin architecture, SwarmGPT provides standard, surface-specific distribution: Codex uses `/skills` and `$skill-name`, while supported ChatGPT Work surfaces use the graphical Plugins Directory and `@` mentions where available.

### Why Separate Skills?
Code orchestration (`codex-swarm`) and image generation (`swarmgpt-imagegen`) have fundamentally different inputs, outputs, verification paths, and failure modes.
* Combining them would violate the single-responsibility principle and bloat the context window.
* Keeping them separate ensures that each workspace handles only what it supports. For instance, if a host workspace lacks image capabilities, `codex-swarm` continues to operate flawlessly while `swarmgpt-imagegen` blocks cleanly without causing runtime failures.

---

## Installation

### Codex

1. Register the repository marketplace from a terminal:
   ```bash
   codex plugin marketplace add Vallykrie/swarmGPT
   ```
2. In Codex, use `/plugins` to browse the added marketplace and install **SwarmGPT**.
3. Use `/skills` in Codex to confirm that both bundled skills are active.
4. Open a fresh Codex session after installation so the plugin and skill catalogs refresh.

### Supported ChatGPT Work surfaces

Open the graphical **Plugins Directory**, locate **SwarmGPT**, and install it if your account and workspace policy allow it. Then open a fresh ChatGPT session and use `@swarmGPT` where plugin mentions are available. Availability depends on the ChatGPT surface, account, and workspace policy.

---

## Invocation & Usage

### Codex
* **`/plugins`**: Browse, install, and manage plugins.
* **`/skills`**: Discover and inspect active skills.
* **Skill invocation**:
  * Invoke the coding swarm: `$codex-swarm`
  * Invoke the image generation swarm: `$swarmgpt-imagegen`

### Supported ChatGPT Work surfaces

Use the graphical **Plugins Directory** for installation and management, then use `@swarmGPT` to target the plugin where mentions are exposed. Support depends on the ChatGPT surface, account eligibility, and workspace administrator policy; Codex-only `/plugins`, `/skills`, and `$skill-name` invocation do not apply here.

> [!WARNING]
> * There is **no `/swarmGPT` slash command** (slash commands are not the distributable mechanism for plugins).
> * The consumer ChatGPT web UI **cannot load arbitrary local skills** or custom plugins; compatibility is limited to supported workspaces.

---

## Automatic Model Routing

Under the `codex-swarm` skill, task complexity is analyzed and work is automatically routed to the prescribed model configuration:

| Work Profile | Target Model | reasoning_effort | Description |
| :--- | :--- | :--- | :--- |
| **Reasoning-Heavy** | `gpt-5.6-sol` | `medium` | Used for ambiguous, risky, architectural changes, debugging, and tricky refactors. |
| **Easy / Boilerplate** | `gpt-5.6-luna` | `max` | Used for isolated work, mechanical updates, docs, bulk edits, and straightforward tests. |

### Routing Guarantees
* **No Silent Substitutions**: If a required model is unavailable or a subtask spawn rejects the model or reasoning effort overrides, the plugin performs exactly one error check. It marks the subtask blocked, logs the routing failure, and halts to request explicit user authorization. It will never silently substitute a model or loop endlessly.

---

## Coordinated Image Workflow

`swarmgpt-imagegen` orchestrates image asset creation and manipulation through the host's native capabilities:

1. **Asset Manifest**: Requests are decomposed into a strict asset manifest specifying purpose, prompt, constraints, destination path, and file format.
2. **One Call Per Asset/Variant**: Exactly one native image generation or edit call is executed per asset or variant. Retries are tracked as separate variants with their own paths.
3. **Safe Bounded Parallelism**: Parallelizes independent asset generation up to the host's concurrency limits; sequential dependency chains are executed in order.
4. **Exclusive Paths**: Every generation task has an exclusive working path. No two tasks may write, copy, or move to the same path concurrently.
5. **Input & Output Inspection**:
   * **Edits**: Existing local inputs are resolved and inspected using a local viewer before being passed as references to the host tool.
   * **Verification**: Outputs are visually inspected for compliance with prompt constraints, and final formats are verified from file contents/metadata, not just the file extension.
6. **Clean Blocking**: Image generation depends entirely on the host exposing its built-in `$imagegen` capability. If that capability is missing, the skill blocks cleanly and lists incomplete items instead of fabricating output.

> [!NOTE]
> No API key is required when the host exposes native image generation under its own authentication and included usage limits. An API/CLI fallback—or larger API-backed batches—may require `OPENAI_API_KEY`.

---

## Native Architecture

SwarmGPT utilizes a lightweight, native-first architecture:
* **Host-Native Subagents**: Collaboration and parallel tasks are managed entirely through the host's native subagent APIs.
* **No MCP Server**: Does not require a Model Context Protocol server.
* **No Standalone CLI**: Operates fully within the ChatGPT/Codex runtime without external dispatch wrappers.
* **Native-First Authentication**: The plugin itself defines no required API key. Native image generation uses host authentication and included limits; API/CLI fallbacks and larger API-backed batches may require `OPENAI_API_KEY`.

---

## Examples

### Multi-Agent Code Swarm (`codex-swarm`)
* **Prompt**:
  ```text
  Use $codex-swarm to migrate the legacy API modules in src/legacy/ and add corresponding unit tests.
  ```
* **Process**: The host decomposes the work, assigning the API logic refactoring (`gpt-5.6-sol`) and unit tests (`gpt-5.6-luna`) to separate subagents under exclusive paths.

### Coordinated Image Batch (`swarmgpt-imagegen`)
* **Prompt**:
  ```text
  Use $swarmgpt-imagegen to generate three icons: a light-mode version at assets/icon-light.png, a dark-mode version at assets/icon-dark.png, and a high-res logo at assets/logo.png.
  ```
* **Process**: The host schedules three parallel, native generation tasks, writes them to their exclusive paths, validates their metadata, and outputs the final paths.

---

## Compatibility Matrix

| Environment / Host | Plugin Loading | `codex-swarm` | `swarmgpt-imagegen` | `@swarmGPT` Mentions |
| :--- | :--- | :--- | :--- | :--- |
| **Codex with plugin and collaboration support** | Supported when enabled by the host | Requires native subagents and required model access | Requires built-in `$imagegen` | Not the invocation path; use `$skill-name` |
| **Supported ChatGPT Work surfaces** | Depends on surface and workspace policy | Depends on exposed skill and collaboration capabilities | Depends on a native image capability | Supported where plugin mentions are exposed |
| **Consumer ChatGPT** | No arbitrary local-skill loading claimed | Not claimed | Not claimed | Surface-dependent; not guaranteed |

---

## Troubleshooting & FAQ

#### Why is there no `/swarmGPT` command?
Top-level custom slash commands are not the distributable mechanism for this plugin. In Codex, use `$codex-swarm`, `$swarmgpt-imagegen`, and `/skills`; on supported ChatGPT Work surfaces, use the graphical Plugins Directory and `@swarmGPT` where mentions are available.

#### Why are the skills not showing up after installation?
In Codex, open a fresh session and check `/skills`. On supported ChatGPT Work surfaces, open a fresh session and confirm installation in the graphical Plugins Directory. Account and workspace policy may restrict availability.

#### What happens if the required models are missing?
The plugin will not silently fall back. It blocks the execution and asks for explicit confirmation before proceeding with any model fallbacks.

#### Can I load arbitrary local skills on consumer ChatGPT?
No, the consumer ChatGPT interface does not support loading arbitrary local skills or plugins.

---

## Repository Tree

```text
.
├── .agents/
│   └── plugins/
│       └── marketplace.json
├── .codex-plugin/
│   └── plugin.json
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-08-03-swarmgpt-public-plugin-design.md
├── skills/
│   ├── codex-swarm/
│   │   ├── SKILL.md
│   │   └── agents/
│   │       └── openai.yaml
│   └── swarmgpt-imagegen/
│       ├── SKILL.md
│       └── agents/
│           └── openai.yaml
├── .gitignore
├── LICENSE
└── README.md
```

---

## Contributing

Contributions are welcome! Please ensure that additions and bug fixes preserve the contracts in the bundled [`codex-swarm`](skills/codex-swarm/SKILL.md) and [`swarmgpt-imagegen`](skills/swarmgpt-imagegen/SKILL.md) skills, including their single-responsibility separation.

Please file issues or submit pull requests directly to the repository homepage: [Vallykrie/swarmGPT](https://github.com/Vallykrie/swarmGPT).

---

## License

This project is licensed under the [MIT License](./LICENSE).

---

## Keywords

`chatgpt`, `codex`, `openai`, `multi-agent`, `subagents`, `agent-skills`, `codex-plugin`, `image-generation`, `developer-tools`, `ai-agents`
