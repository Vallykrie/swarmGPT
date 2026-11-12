#!/usr/bin/env bash
# Test list-models.sh and dispatch.sh model validation against a fake codex.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
export CODEX="$ROOT/tests/fake-codex.sh"
fail() { echo "tests/models.sh: $*" >&2; exit 1; }

got="$(bash "$ROOT/scripts/list-models.sh" --tsv | cut -f1 | sort | tr '\n' ' ')"
[ "$got" = "gpt-9-astra gpt-9-luna " ] || fail "list-models kept the wrong models: $got"
[ "$(bash "$ROOT/scripts/list-models.sh" --tsv | awk -F'\t' '$1 == "gpt-9-astra" { print $2 "|" $3 }')" = "high,ultra|high" ] || \
  fail "list-models reported the wrong efforts"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cd "$work"
printf 'MODEL: gpt-9-luna\n\nhi\n' > 01-default.prompt.md
printf 'MODEL: gpt-9-astra\nEFFORT: ultra\n\nhi\n' > 02-effort.prompt.md
printf 'MODEL: gpt-8.5-luna\n\nhi\n' > 03-old.prompt.md
printf 'MODEL: gpt-9-luna\nEFFORT: ultra\n\nhi\n' > 04-bad-effort.prompt.md

bash "$ROOT/scripts/dispatch.sh" --log-root logs 01-default.prompt.md 02-effort.prompt.md >/dev/null || \
  fail "dispatch rejected current models"
grep -q 'ran gpt-9-luna/medium' logs/*/01-default.last || fail "default effort not applied"
grep -q 'ran gpt-9-astra/ultra' logs/*/02-effort.last || fail "EFFORT header not applied"

for bad in 03-old 04-bad-effort; do
  if bash "$ROOT/scripts/dispatch.sh" --log-root "logs-$bad" 01-default.prompt.md "$bad.prompt.md" >/dev/null 2>&1; then
    fail "dispatch accepted $bad"
  fi
  [ ! -e "logs-$bad" ] || fail "refused dispatch ($bad) still created a run directory"
done

echo "tests/models.sh: ok"
