# SwarmGPT Public Plugin Design Specification

## 1. Goal and Non-Goals
**Goal:** Convert the standalone Codex skill repository (`swarmgpt`) into an installable, public, skills-only universal plugin for ChatGPT and Codex, enabling wide distribution through the marketplace.
**Non-Goals:**
- Do not implement custom UI components or host-side runtime modifications.
- Do not create a new standalone CLI or external orchestrator.
- Do not introduce paid or required third-party API keys (e.g., for image generation testing).

## 2. Product Truth
Skills are the foundational unit of interaction.
- They are invoked using `$skill-name` in Codex.
- They are selected through the `/skills` menu.
- They can be triggered using `@` mentions (e.g., `@swarmGPT`) on supported ChatGPT surfaces.
- **Explicit Restriction:** Arbitrary new top-level slash commands (e.g., `/swarmGPT`) are not the distributable mechanism.
- **Explicit Restriction:** Deprecated local custom prompts must not be used.

## 3. Plugin Architecture
The repository will be structured as a standard universal plugin leveraging native capabilities:
- **`.codex-plugin/plugin.json`**: Required manifest at the repository root defining the plugin.
- **`skills/`**: Located at the plugin root, containing all bundled skills.
- **`.agents/plugins/marketplace.json`**: Repository marketplace metadata.
- **No MCP Server**: Both multi-agent coordination and image generation workflows rely entirely on native host capabilities, requiring no external Model Context Protocol server.

## 4. Bundled Skills
The plugin will bundle exactly two focused skills:

### 4.1 `codex-swarm`
The existing skill for orchestrating multi-agent code, content, and research work.
- Retains exact automatic model routing based on task complexity:
  - Heavy, complex, or risky work: `gpt-5.6-sol` with `reasoning_effort: medium`.
  - Easy, mechanical, or documentation work: `gpt-5.6-luna` with `reasoning_effort: max`.
- Maintains rigorous decomposition, integration verification, and persistent audit logging.

### 4.2 `swarmgpt-imagegen` (New)
A new skill for generating or editing one or many images.
- Uses native image generation capabilities (equivalent to `$imagegen`).
- Safely parallelizes independent image generation batches when useful.
- Inspects generated outputs and strictly preserves requested paths and file formats.
- Fails gracefully and never claims to support consumer surfaces or tools that are unavailable in the host environment.

## 5. Public Install and Invocation UX
- **Installation:** Users install the plugin via the marketplace add/install flow from the repository `Vallykrie/swarmGPT`.
- **Invocation in Codex:** Use `$codex-swarm` and `$swarmgpt-imagegen` directly, or discover them via the `/skills` menu.
- **Invocation in ChatGPT:** Use `@swarmGPT` or mention the bundled skill on supported ChatGPT Work surfaces.
- **Availability:** Plugin and skill availability depends entirely on the host's supported surfaces and the user's workspace policy.

## 6. Public README and SEO Plan
The `README.md` will be rewritten to optimize for marketplace discovery and user onboarding:
- **Title & Opening:** Keyword-rich title and first paragraph clearly explaining the value proposition without keyword stuffing.
- **Badges:** Standard build, version, and license badges.
- **Feature Table:** Quick overview of capabilities.
- **Quick Start & Installation:** Clear marketplace installation instructions.
- **Invocation & Usage:** Examples of `$codex-swarm`, `$swarmgpt-imagegen`, and `@swarmGPT`.
- **Model Routing:** Explanation of the automatic `gpt-5.6-sol`/`gpt-5.6-luna` routing.
- **Image Generation:** Guide on using the new parallel image generation capabilities.
- **Architecture:** Brief explanation of the native subagent and tool approach.
- **Examples:** Concrete use cases for both skills.
- **Compatibility Matrix:** Clear requirements for Codex and ChatGPT Work surfaces.
- **Troubleshooting & FAQ:** Common issues (e.g., missing model access, unavailable surfaces).
- **Contributing & License:** Standard open-source guidelines.
- **Terminology:** Accurate use of official OpenAI terminology throughout.

## 7. GitHub Metadata Plan
To maximize discoverability on GitHub:
- **About Description:** A concise summary of the plugin's purpose (e.g., "A universal plugin for Codex and ChatGPT providing multi-agent orchestration and parallel image generation.").
- **URLs:** Proper configuration of the repository homepage URL.
- **Topics:** Exactly this focused list: `chatgpt`, `codex`, `openai`, `multi-agent`, `subagents`, `agent-skills`, `codex-plugin`, `image-generation`, `developer-tools`, `ai-agents`.

## 8. Visual Assets
- Plugin icons, logos, and social preview images are strictly optional unless explicitly generated, verified, and placed in the correct paths.
- No broken asset paths in manifests are permitted.
- **Recommended Initial Scope:** Launch with text metadata only.
- **Future Enhancement:** Add visual assets in a later, dedicated pass once verified.

## 9. Error Handling
The plugin and its skills must handle host environment constraints gracefully:
- **Missing Model Overrides:** Mark the affected task blocked and request explicit authorization before using any fallback if `gpt-5.6-sol` or `gpt-5.6-luna` is unavailable; never substitute silently.
- **Unavailable Tools:** Report blocked status if collaboration primitives or native image tools are not exposed by the host.
- **Unsupported Surfaces:** Clearly indicate when a requested action (e.g., `@` mention) is not supported in the current interface.
- **Install/Cache Issues:** Guide the user to refresh the skill catalog or restart their session if a newly installed skill is not found.
- **Permissions:** Respect path restrictions and write permissions; skip persistent logging (e.g., `.codex-swarm/logs/`) if unauthorized or unwritable.

## 10. Testing and Acceptance Criteria
Before release, the plugin must pass the following checks:
- **Validation:** All JSON and YAML manifests (including `plugin.json` and `marketplace.json`) are valid. Skill markdown files (`SKILL.md`) parse correctly.
- **Path Resolution:** Marketplace metadata paths resolve correctly relative to the repository root.
- **Negative Trigger Tests:** Ensure the skills do not trigger on read-only queries or trivial single-file edits.
- **Routing Pressure Tests:** Verify that `codex-swarm` strictly adheres to the `gpt-5.6-sol` (medium) and `gpt-5.6-luna` (max) mapping without silently substituting.
- **Image Workflow:** Forward test the `swarmgpt-imagegen` parallel execution flow without requiring a paid API key.
- **Visibility:** Verify that a fresh session correctly displays the installed skills via the `/skills` menu.
- **Documentation:** All links in the README resolve correctly.
- **Git State:** Ensure the repository has a clean git state and passes remote push verification.

## 11. Proposed Repository Tree
```text
swarmgpt/
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

## 12. Risks and Decisions
- **Why a Plugin instead of a Deprecated Custom Slash Prompt?**
  Top-level slash commands and custom prompt files are not standard distributable mechanisms across modern Codex and ChatGPT surfaces. Adopting the universal plugin architecture (`.codex-plugin/plugin.json` and `skills/`) guarantees standard discovery via `/skills`, `$skill-name`, and `@` mentions, and ensures compatibility with marketplace distribution.
- **Why is Image Generation a Separate Skill?**
  Image generation has fundamentally different inputs, outputs, verification steps, and failure modes compared to code/content orchestration. Mixing them would violate the single-responsibility principle, bloat the `codex-swarm` context window, and cause unpredictable behavior when the host lacks image generation capabilities. Keeping `swarmgpt-imagegen` separate allows users to compose the tools explicitly and ensures the core multi-agent code orchestration remains hyper-focused and reliable.
