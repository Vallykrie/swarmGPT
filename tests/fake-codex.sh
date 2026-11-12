#!/usr/bin/env bash
# Stand-in for the Codex CLI used by tests/models.sh.
case "${1:-}" in
  --version) echo "codex-cli 99.0.0" ;;
  debug)
    cat <<'JSON'
{"models": [
 {"slug": "gpt-9-luna", "visibility": "list", "description": "Fast model.",
  "default_reasoning_level": "medium", "upgrade": null,
  "supported_reasoning_levels": [{"effort": "low"}, {"effort": "medium"}, {"effort": "high"}]},
 {"slug": "gpt-8.5-luna", "visibility": "list", "description": "Older fast model.",
  "default_reasoning_level": "medium", "upgrade": null,
  "supported_reasoning_levels": [{"effort": "low"}, {"effort": "medium"}]},
 {"slug": "gpt-8.5-terra", "visibility": "list", "description": "Older balanced model.",
  "default_reasoning_level": "medium", "upgrade": {"model": "gpt-9-luna"},
  "supported_reasoning_levels": [{"effort": "medium"}]},
 {"slug": "gpt-9-astra", "visibility": "list", "description": "Frontier model.",
  "default_reasoning_level": "high", "upgrade": null,
  "supported_reasoning_levels": [{"effort": "high"}, {"effort": "ultra"}]},
 {"slug": "secret-model", "visibility": "hide", "description": "Hidden.",
  "default_reasoning_level": "low", "upgrade": null,
  "supported_reasoning_levels": [{"effort": "low"}]}
]}
JSON
    ;;
  exec)
    shift; model=""; effort=""; last=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --model) model="$2"; shift ;;
        -c) effort="${2#model_reasoning_effort=}"; shift ;;
        -o) last="$2"; shift ;;
      esac
      shift
    done
    echo "ran $model/$effort" | tee "$last"
    ;;
esac
