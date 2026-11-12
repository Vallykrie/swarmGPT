#!/usr/bin/env bash
# list-models.sh — list the Codex models the installed `codex` CLI can run for
# this account right now, newest version of each family only.
#
# Usage:
#   list-models.sh          table for the orchestrator to choose from
#   list-models.sh --tsv    one "slug<TAB>efforts,comma,separated<TAB>default
#                           effort" line per model (used by dispatch.sh)
#   list-models.sh --codex-path   print the codex binary that will be used
#
# The list comes from `codex debug models` at call time, so new releases show
# up without editing this repository. Hidden models and models the catalog
# marks as superseded (an `upgrade` target) are dropped. A "family" is the
# slug minus its version (gpt-<version>-luna -> luna); for each family only
# the highest version is kept, so older generations never appear.
#
# When several `codex` binaries are on PATH (an old one in ~/.local/bin
# shadowing a newer npm install, say), the newest version is used, because
# newer CLIs can run newer models.
#
# Environment:
#   CODEX   codex binary to call (default: the newest `codex` on PATH)
#
# Requires python3 to parse the catalog JSON.
# Exit code: 0 on success, 1 if codex or python3 is missing, the catalog
# cannot be read, or it lists no usable model.

set -u

FORMAT="table"

case "${1:-}" in
  '') ;;
  --tsv) FORMAT="tsv" ;;
  --codex-path) FORMAT="path" ;;
  -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
  *) echo "list-models: unknown option: $1" >&2; exit 1 ;;
esac

# newest_codex — print the highest-version `codex` on PATH
newest_codex() {
  local bin ver best="" best_ver=""
  while IFS= read -r bin; do
    ver="$("$bin" --version 2>/dev/null | awk '{ print $NF; exit }')"
    [ -n "$ver" ] || continue
    if [ -z "$best" ] || awk -v a="$ver" -v b="$best_ver" 'BEGIN {
        n = split(a, x, /[.-]/); m = split(b, y, /[.-]/); if (m > n) n = m
        for (i = 1; i <= n; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 }
        exit 1 }'; then
      best="$bin"; best_ver="$ver"
    fi
  done < <(type -ap codex | awk '!seen[$0]++')
  printf '%s\n' "$best"
}

CODEX="${CODEX:-$(newest_codex)}"
if [ -z "$CODEX" ] || ! command -v "$CODEX" >/dev/null 2>&1; then
  echo "list-models: 'codex' not found on PATH — install the Codex CLI first" >&2
  exit 1
fi
if [ "$FORMAT" = "path" ]; then
  command -v "$CODEX"
  exit 0
fi
command -v python3 >/dev/null 2>&1 || {
  echo "list-models: python3 is required to read the Codex model catalog" >&2
  exit 1
}

catalog="$("$CODEX" debug models 2>/dev/null)" || {
  echo "list-models: '$CODEX debug models' failed — upgrade the Codex CLI and run 'codex login'" >&2
  exit 1
}

printf '%s' "$catalog" | python3 -I -c '
import json, re, sys

fmt = sys.argv[1]
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit("list-models: codex returned an unreadable model catalog")
models = data.get("models", []) if isinstance(data, dict) else data

def version_key(v):
    return tuple(int(p) for p in v.split(".")) if v else ()

rows = []
for m in models:
    if not isinstance(m, dict) or m.get("visibility") != "list" or m.get("upgrade"):
        continue
    slug = str(m.get("slug") or "")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", slug):
        continue
    match = re.fullmatch(r"[a-z]+-([0-9]+(?:\.[0-9]+)*)-(.+)", slug)
    version, family = (match.group(1), match.group(2)) if match else ("", slug)
    efforts = [str(r.get("effort")) for r in m.get("supported_reasoning_levels") or []
               if isinstance(r, dict) and r.get("effort")]
    default = str(m.get("default_reasoning_level") or (efforts[0] if efforts else "medium"))
    rows.append(dict(slug=slug, version=version, family=family, efforts=efforts,
                     default=default, desc=str(m.get("description") or "")))

best = {}
for r in rows:
    if r["family"] not in best or version_key(r["version"]) > version_key(best[r["family"]]):
        best[r["family"]] = r["version"]
rows = [r for r in rows if r["version"] == best[r["family"]]]
if not rows:
    sys.exit("list-models: the Codex catalog lists no usable model")

if fmt == "tsv":
    for r in rows:
        print("\t".join([r["slug"], ",".join(r["efforts"]), r["default"]]))
else:
    print("%-18s %-8s %-10s %-34s %s" % ("MODEL", "VERSION", "FAMILY", "EFFORTS (default*)", "DESCRIPTION"))
    for r in rows:
        efforts = ",".join(e + ("*" if e == r["default"] else "") for e in r["efforts"]) or "-"
        print("%-18s %-8s %-10s %-34s %s" % (r["slug"], r["version"] or "-", r["family"], efforts, r["desc"]))
' "$FORMAT"
