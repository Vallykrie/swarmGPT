# SwarmGPT: Multi-Agent Orchestration & Native Image Generation for ChatGPT and Codex

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0-blue.svg)](.codex-plugin/plugin.json)
[![Compatibility: ChatGPT + Codex](https://img.shields.io/badge/Compatibility-ChatGPT%20%2B%20Codex-brightgreen.svg)](#compatibility-matrix)

SwarmGPT is a universal, skills-only plugin designed for ChatGPT and Codex that brings robust multi-agent orchestration and coordinated native image generation directly into your AI workspace. By leveraging native host capabilities without relying on external servers, CLI orchestrators, or third-party API keys, SwarmGPT enables developer teams to seamlessly route complex coding tasks to specialized subagents and coordinate advanced parallel image generation workflows.

---

## Feature Overview

| Skill | Invocation Trigger | Primary Purpose | Key Features & Capabilities |
| :--- | :--- | :--- | :--- |
| **[`codex-swarm`](skills/codex-swarm/SKILL.md)** | `$codex-swarm`<br>(or selection via `/skills` / `@swarmGPT` mention) | Multi-agent task decomposition, parallel coding, and review. | • Automatic model routing (`gpt-5.6-sol` / `gpt-5.6-luna`) based on complexity.<br>• Parallel subagent execution with bounded turns.<br>• Integration-level verification and audit logs. |
| **[`swarmgpt-imagegen`](skills/swarmgpt-imagegen/SKILL.md)** | `$swarmgpt-imagegen`<br>(or selection via `/skills`) | Native image generation and editing coordination. | • Bounded parallel generation of multiple assets/variants.<br>• Native input inspection, reference passing, and verification.<br>• Cleanly blocks if required host tools are unavailable. |

---

## Why / What

### Why a Plugin?
Traditional custom slash prompts or custom command scripts are difficult to distribute and manage across multiple modern AI surfaces. By aligning with the universal plugin architecture, SwarmGPT provides a standard distribution mechanism: discovery via `/skills`, direct invocation via `$skill-name`, and targeted interactions via `@` mentions where the host supports them.

### Why Separate Skills?
Code orchestration (`codex-swarm`) and image generation (`swarmgpt-imagegen`) have fundamentally different inputs, outputs, verification paths, and failure modes.
* Combining them would violate the single-responsibility principle and bloat the context window.
* Keeping them separate ensures that each workspace handles only what it supports. For instance, if a host workspace lacks image capabilities, `codex-swarm` continues to operate flawlessly while `swarmgpt-imagegen` blocks cleanly without causing runtime failures.

---

## Installation

To add the SwarmGPT plugin to your environment, follow these steps:

1. Run the following command in your terminal to register the plugin with your marketplace:
   ```bash
   codex plugin marketplace add Vallykrie/swarmGPT
   ```
2. Open the plugin browser by entering `/plugins` in your interface and confirm the installation of **SwarmGPT**.
3. Discover and verify the active skills by typing `/skills`.
4. **Important:** After installation, you **must open a fresh ChatGPT or Codex session** to reload the plugin and refresh the skill catalog.

---

## Invocation & Usage

### Interface Navigation
* **`/plugins`**: Used to browse, install, and manage plugins in your environment.
* **`/skills`**: Used to discover, search, and inspect the catalog of active skills.

### Invocation Commands
* **Codex Workspaces**:
  * Invoke the coding swarm: `$codex-swarm`
  * Invoke the image generation swarm: `$swarmgpt-imagegen`
* **ChatGPT surfaces**:
  * On supported ChatGPT Work or Enterprise workspaces, use `@swarmGPT` mentions to target the plugin directly, subject to surface availability and workspace administration policies.

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
> SwarmGPT does not guarantee API-key-free image generation unless the hosting platform provides a built-in, unauthenticated capability.

---

## Native Architecture

SwarmGPT utilizes a lightweight, native-first architecture:
* **Host-Native Subagents**: Collaboration and parallel tasks are managed entirely through the host's native subagent APIs.
* **No MCP Server**: Does not require a Model Context Protocol server.
* **No Standalone CLI**: Operates fully within the ChatGPT/Codex runtime without external dispatch wrappers.
* **No Required Third-Party Keys**: The plugin defines no required external API key; image availability and authentication remain the responsibility of the host.

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
Slash commands are not standard distributable mechanisms for universal plugins. Instead, SwarmGPT uses standard `$codex-swarm` and `$swarmgpt-imagegen` invocations, `/skills` discovery, and `@swarmGPT` mentions where supported.

#### Why are the skills not showing up after installation?
Ensure you have opened a fresh ChatGPT/Codex session so the host refreshes its skill catalog.

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
