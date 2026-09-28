#!/usr/bin/env bash
# dispatch.sh — launch a swarm of parallel `codex exec` (Codex CLI / GPT) jobs.
#
# Each TASKFILE is a subtask prompt file. Its first line must be a model
# header naming a routing tier (preferred) or a literal Codex model slug; an
# EFFORT header may follow and overrides the tier's effort:
#
#     MODEL: medium
#
#     <the subtask prompt, any number of lines>
#
# Tiers (heavy, medium, light) are resolved through routing.conf. The table is
# refreshed from GitHub at most once per SWARMGPT_ROUTING_TTL seconds and
# cached under ~/.cache/swarmgpt/, so model changes reach every install
# without a plugin update. Resolution order: $SWARMGPT_ROUTING (explicit
# file) > the newer of the cached remote table and the bundled routing.conf.
#
# Jobs are launched concurrently and waited on. Raw output is collected under
# LOG_ROOT/<ISO-timestamp>/ :
#
#     <name>.out      raw codex stdout (final message + event stream)
#     <name>.err      raw codex stderr
#     <name>.last     just the agent's final message (codex -o)
#     results.tsv     name <TAB> model <TAB> effort <TAB> exit_code <TAB> seconds
#
# A short per-job status table is printed to stdout (safe to read into an
# agent's context — raw Codex output is NOT printed).
#
# Usage:
#   dispatch.sh [--auto | --readonly | --yolo] [--timeout DUR] [--jobs N]
#               [--log-root DIR] TASKFILE...
#
#   --auto      codex runs with --sandbox workspace-write (default): it may
#               write inside the project, network disabled, no approvals.
#   --readonly  codex runs with --sandbox read-only: analysis/research jobs
#               that report back instead of editing files.
#   --yolo      codex runs with --dangerously-bypass-approvals-and-sandbox.
#               No sandbox at all. Only for externally sandboxed environments.
#   --timeout   per-job wall-clock limit, e.g. 15m, 900s, 1h (default: 20m)
#   --jobs      max concurrent codex sessions, 0 = unlimited (default: 0)
#   --log-root  where run directories are created (default: .codex-swarm/logs)
#   --print-routing  print the resolved routing table and exit
#
# Environment:
#   SWARMGPT_ROUTING      path to a routing file to use instead (no fetch)
#   SWARMGPT_OFFLINE=1    never fetch; use the cache or the bundled table
#   SWARMGPT_ROUTING_URL  where to fetch the live table from
#   SWARMGPT_ROUTING_TTL  seconds between fetch attempts (default: 86400)
#
# Exit code: 0 if every job succeeded, 1 otherwise.

set -u

MODE="auto"
TIMEOUT="20m"
JOBS=0
LOG_ROOT=".codex-swarm/logs"
PRINT_ROUTING=0
TASKFILES=()

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --auto)     MODE="auto" ;;
    --readonly) MODE="readonly" ;;
    --yolo)     MODE="yolo" ;;
    --timeout)  shift; TIMEOUT="${1:?--timeout needs a value}" ;;
    --jobs)     shift; JOBS="${1:?--jobs needs a value}" ;;
    --log-root) shift; LOG_ROOT="${1:?--log-root needs a value}" ;;
    --print-routing) PRINT_ROUTING=1 ;;
    -h|--help)  usage 0 ;;
    -*)         echo "dispatch.sh: unknown option: $1" >&2; usage 1 ;;
    *)          TASKFILES+=("$1") ;;
  esac
  shift
done

# --- model routing ---------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLED_ROUTING="$SCRIPT_DIR/routing.conf"
ROUTING_URL="${SWARMGPT_ROUTING_URL:-https://raw.githubusercontent.com/Vallykrie/swarmGPT/main/scripts/routing.conf}"
ROUTING_TTL="${SWARMGPT_ROUTING_TTL:-86400}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/swarmgpt"
CACHED_ROUTING="$CACHE_DIR/routing.conf"
LAST_CHECK="$CACHE_DIR/last-check"

valid_routing() {
  # valid_routing FILE — strict grammar, so a fetched table can only ever name
  # models, efforts and a minimum CLI version; any other line rejects the file
  [ -s "$1" ] || return 1
  awk '
    /^[[:space:]]*(#|$)/ { next }
    $1 == "min-codex" && NF == 2 && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ { next }
    NF == 3 && $1 ~ /^[a-z][a-z0-9-]*$/ && $2 ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/ &&
      $3 ~ /^(minimal|low|medium|high|xhigh|max|ultra)$/ { tiers++; next }
    { bad = 1 }
    END { exit (bad || !tiers) }
  ' "$1"
}

mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

refresh_routing() {
  # at most one fetch attempt per TTL window; failures keep the old cache
  [ "${SWARMGPT_OFFLINE:-0}" = "1" ] && return
  command -v curl >/dev/null 2>&1 || return
  if [ -f "$LAST_CHECK" ] && [ $(( $(date +%s) - $(mtime "$LAST_CHECK") )) -lt "$ROUTING_TTL" ]; then
    return
  fi
  mkdir -p "$CACHE_DIR" 2>/dev/null || return
  touch "$LAST_CHECK"
  local tmp="$CACHED_ROUTING.$$"
  if curl -fsSL --max-time 5 "$ROUTING_URL" -o "$tmp" 2>/dev/null && valid_routing "$tmp"; then
    mv -f "$tmp" "$CACHED_ROUTING"
  else
    rm -f "$tmp"
  fi
}

ROUTING_FILE=""
ROUTING_SRC="none"
if [ -n "${SWARMGPT_ROUTING:-}" ]; then
  valid_routing "$SWARMGPT_ROUTING" || {
    echo "dispatch.sh: SWARMGPT_ROUTING=$SWARMGPT_ROUTING is missing or malformed" >&2; exit 1; }
  ROUTING_FILE="$SWARMGPT_ROUTING"; ROUTING_SRC="override ($SWARMGPT_ROUTING)"
else
  refresh_routing
  if valid_routing "$CACHED_ROUTING" &&
     { ! valid_routing "$BUNDLED_ROUTING" ||
       [ "$(mtime "$CACHED_ROUTING")" -ge "$(mtime "$BUNDLED_ROUTING")" ]; }; then
    ROUTING_FILE="$CACHED_ROUTING"; ROUTING_SRC="remote, cached from $ROUTING_URL"
  elif valid_routing "$BUNDLED_ROUTING"; then
    ROUTING_FILE="$BUNDLED_ROUTING"; ROUTING_SRC="bundled ($BUNDLED_ROUTING)"
  fi
fi

route() {
  # route TIER — prints "<model> <effort>", or nothing if TIER is not a tier
  [ -n "$ROUTING_FILE" ] || return 0
  awk -v t="$1" '$1 == t && NF == 3 { print $2, $3; exit }' "$ROUTING_FILE"
}

MIN_CODEX=""
[ -n "$ROUTING_FILE" ] && MIN_CODEX="$(awk '$1 == "min-codex" { print $2; exit }' "$ROUTING_FILE")"

if [ "$PRINT_ROUTING" = "1" ]; then
  echo "routing source: $ROUTING_SRC"
  [ -n "$ROUTING_FILE" ] || exit 1
  [ -n "$MIN_CODEX" ] && echo "min codex:      $MIN_CODEX"
  awk '!/^[[:space:]]*(#|$)/ && NF == 3 { printf "  %-8s -> %s / %s\n", $1, $2, $3 }' "$ROUTING_FILE"
  exit 0
fi

[ "${#TASKFILES[@]}" -gt 0 ] || { echo "dispatch.sh: no task files given" >&2; usage 1; }

command -v codex >/dev/null 2>&1 || {
  echo "dispatch.sh: 'codex' not found on PATH — install the Codex CLI first:" >&2
  echo "  npm install -g @openai/codex   (or: brew install codex)" >&2
  exit 1
}

version_lt() {
  # version_lt A B — true when A < B, comparing major.minor.patch numerically
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, /[.-]/); split(b, y, /[.-]/)
    for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) exit 0; if (x[i] + 0 > y[i] + 0) exit 1 }
    exit 1 }'
}

if [ -n "$MIN_CODEX" ]; then
  CODEX_VERSION="$(codex --version 2>/dev/null | awk '{ print $NF; exit }')"
  if [ -n "$CODEX_VERSION" ] && version_lt "$CODEX_VERSION" "$MIN_CODEX"; then
    echo "dispatch.sh: codex $CODEX_VERSION at $(command -v codex) is too old; the routed models need $MIN_CODEX+." >&2
    echo "  upgrade:  npm install -g @openai/codex@latest   (or: brew upgrade codex)" >&2
    echo "  then check 'which -a codex' — an older copy earlier on PATH still wins." >&2
    exit 1
  fi
fi

MODELS_CACHE="${CODEX_HOME:-$HOME/.codex}/models_cache.json"

# --- normalize the timeout to whole seconds -------------------------------
case "$TIMEOUT" in
  *h) TIMEOUT_S=$(( ${TIMEOUT%h} * 3600 )) ;;
  *m) TIMEOUT_S=$(( ${TIMEOUT%m} * 60 )) ;;
  *s) TIMEOUT_S=${TIMEOUT%s} ;;
  *)  TIMEOUT_S=$TIMEOUT ;;
esac
case "$TIMEOUT_S" in
  ''|*[!0-9]*) echo "dispatch.sh: bad --timeout: $TIMEOUT" >&2; exit 1 ;;
esac

TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
RUN_DIR="$LOG_ROOT/$TS"
mkdir -p "$RUN_DIR" || { echo "dispatch.sh: cannot create $RUN_DIR" >&2; exit 1; }

ROOT="$(pwd)"

CODEX_FLAGS=(--cd "$ROOT" --skip-git-repo-check)
case "$MODE" in
  auto)     CODEX_FLAGS+=(--sandbox workspace-write) ;;
  readonly) CODEX_FLAGS+=(--sandbox read-only) ;;
  yolo)     CODEX_FLAGS+=(--dangerously-bypass-approvals-and-sandbox) ;;
esac

run_one() {
  # run_one NAME MODEL EFFORT PROMPTFILE — one background subshell per job
  local name="$1" model="$2" effort="$3" promptfile="$4"
  local start end rc pid watchdog

  start="$(date +%s)"

  codex exec "$(cat "$promptfile")" \
      --model "$model" \
      -c model_reasoning_effort="$effort" \
      -o "$RUN_DIR/$name.last" \
      "${CODEX_FLAGS[@]}" \
      > "$RUN_DIR/$name.out" 2> "$RUN_DIR/$name.err" &
  pid=$!

  # wall-clock watchdog: codex exec has no built-in timeout flag
  ( sleep "$TIMEOUT_S"; kill -TERM "$pid" 2>/dev/null; sleep 5; kill -KILL "$pid" 2>/dev/null ) &
  watchdog=$!

  # stderr redirected: suppress the shell's "Terminated" job-control notice
  # when the watchdog kills a job
  { wait "$pid"; rc=$?; } 2>/dev/null
  { kill "$watchdog"; wait "$watchdog"; } 2>/dev/null

  end="$(date +%s)"
  if [ "$rc" -ge 124 ] && [ ! -s "$RUN_DIR/$name.last" ]; then
    echo "dispatch.sh: job timed out after ${TIMEOUT_S}s" >> "$RUN_DIR/$name.err"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$model" "$effort" "$rc" "$((end - start))" \
    > "$RUN_DIR/$name.meta"
  return "$rc"
}

NAMES=()
PIDS=()

for f in "${TASKFILES[@]}"; do
  [ -f "$f" ] || { echo "dispatch.sh: task file not found: $f" >&2; exit 1; }

  header="$(head -n 1 "$f")"
  case "$header" in
    [Mm][Oo][Dd][Ee][Ll]:*) ;;
    *) echo "dispatch.sh: $f: first line must be 'MODEL: <tier or codex model slug>'" >&2; exit 1 ;;
  esac
  model="$(printf '%s' "$header" | sed 's/^[Mm][Oo][Dd][Ee][Ll]:[[:space:]]*//')"
  [ -n "$model" ] || { echo "dispatch.sh: $f: empty MODEL header" >&2; exit 1; }

  tier=""
  effort="medium"
  resolved="$(route "$model")"
  if [ -n "$resolved" ]; then
    tier="$model"; model="${resolved% *}"; effort="${resolved#* }"
  else
    case "$model" in
      heavy|medium|light)
        echo "dispatch.sh: $f: tier '$model' needs a routing table, but none was found" >&2; exit 1 ;;
    esac
  fi

  body_from=2
  line2="$(sed -n '2p' "$f")"
  case "$line2" in
    [Ee][Ff][Ff][Oo][Rr][Tt]:*)
      effort="$(printf '%s' "$line2" | sed 's/^[Ee][Ff][Ff][Oo][Rr][Tt]:[[:space:]]*//')"
      body_from=3
      ;;
  esac
  [ -n "$effort" ] || { echo "dispatch.sh: $f: empty EFFORT header" >&2; exit 1; }

  if [ -f "$MODELS_CACHE" ] && ! grep -q "\"$model\"" "$MODELS_CACHE"; then
    echo "dispatch.sh: warning: $model is not in your local Codex model list ($MODELS_CACHE); the job may fail" >&2
  fi

  name="$(basename "$f")"
  name="${name%.prompt.md}"; name="${name%.md}"; name="${name%.txt}"

  promptfile="$RUN_DIR/$name.prompt"
  printf 'Working directory for this task: %s — resolve all relative paths against it.\n\n' \
    "$ROOT" > "$promptfile"
  tail -n +"$body_from" "$f" | sed '1{/^[[:space:]]*$/d;}' >> "$promptfile"
  tail -n +"$body_from" "$f" | grep -q '[^[:space:]]' || {
    echo "dispatch.sh: $f: prompt body is empty" >&2; exit 1; }

  # bounded concurrency (0 = unlimited)
  if [ "$JOBS" -gt 0 ]; then
    while [ "$(jobs -pr | wc -l)" -ge "$JOBS" ]; do sleep 1; done
  fi

  run_one "$name" "$model" "$effort" "$promptfile" &
  PIDS+=($!)
  NAMES+=("$name")
  echo "dispatched: $name  [${tier:+$tier -> }$model/$effort]  (pid $!)"
done

echo "routing: $ROUTING_SRC"
echo "waiting on ${#PIDS[@]} parallel codex job(s), ${TIMEOUT_S}s cap each..."

FAILED=0
for i in "${!PIDS[@]}"; do
  wait "${PIDS[$i]}" || FAILED=1
done

rm -f "$RUN_DIR"/*.prompt

RESULTS="$RUN_DIR/results.tsv"
: > "$RESULTS"
echo ""
echo "run directory: $RUN_DIR"
printf '%-24s %-16s %-8s %-6s %s\n' "SUBTASK" "MODEL" "EFFORT" "STATUS" "SECONDS"
for name in "${NAMES[@]}"; do
  if [ -f "$RUN_DIR/$name.meta" ]; then
    IFS=$'\t' read -r _ model effort rc secs < "$RUN_DIR/$name.meta"
    cat "$RUN_DIR/$name.meta" >> "$RESULTS"
  else
    model="?"; effort="?"; rc="?"; secs="?"
    printf '%s\t?\t?\t?\t?\n' "$name" >> "$RESULTS"
  fi
  status="ok"; [ "$rc" = "0" ] || status="FAIL"
  printf '%-24s %-16s %-8s %-6s %s\n' "$name" "$model" "$effort" "$status" "$secs"
done

exit "$FAILED"
