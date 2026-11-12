#!/usr/bin/env bash
# dispatch.sh — launch a swarm of parallel `codex exec` (Codex CLI / GPT) jobs.
#
# Each TASKFILE is a subtask prompt file. Its first line must name a Codex
# model; an EFFORT header may follow:
#
#     MODEL: <model slug from list-models.sh>
#     EFFORT: <one of that model's efforts>     (optional)
#
#     <the subtask prompt, any number of lines>
#
# The orchestrator picks the model and effort per subtask from the live list
# printed by list-models.sh (next to this script), which reads `codex debug
# models`. Before any job starts, every header is checked against that list:
# the model must be a current, listed model and the effort one it supports
# (omitted = the model's default). One bad file refuses the whole run, so a
# swarm never starts half-way. Jobs run on the same codex binary the list
# came from (the newest `codex` on PATH).
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
#   dispatch.sh --list-models
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
#   --list-models  print the models this run can use and exit
#
# Environment:
#   CODEX   codex binary to use (default: the newest `codex` on PATH)
#
# Exit code: 0 if every job succeeded, 1 otherwise.

set -u

MODE="auto"
TIMEOUT="20m"
JOBS=0
LOG_ROOT=".codex-swarm/logs"
LIST_ONLY=0
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
    --list-models) LIST_ONLY=1 ;;
    -h|--help)  usage 0 ;;
    -*)         echo "dispatch.sh: unknown option: $1" >&2; usage 1 ;;
    *)          TASKFILES+=("$1") ;;
  esac
  shift
done

# --- live model list -------------------------------------------------------
LISTER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/list-models.sh"
[ -f "$LISTER" ] || { echo "dispatch.sh: model lister not found: $LISTER" >&2; exit 1; }

if [ "$LIST_ONLY" = "1" ]; then
  exec bash "$LISTER"
fi

[ "${#TASKFILES[@]}" -gt 0 ] || { echo "dispatch.sh: no task files given" >&2; usage 1; }

CODEX="$(bash "$LISTER" --codex-path)" || {
  echo "  install:  npm install -g @openai/codex   (or: brew install codex)" >&2
  exit 1
}
export CODEX
# one "slug<TAB>efforts,comma,separated<TAB>default effort" line per model
AVAILABLE="$(bash "$LISTER" --tsv)" || { echo "dispatch.sh: cannot list Codex models" >&2; exit 1; }

show_models() {
  printf '%s\n' "$AVAILABLE" |
    awk -F'\t' '{ printf "  %-18s efforts: %s (default %s)\n", $1, $2, $3 }' >&2
}

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

# --- validate every task file before anything launches ---------------------
NAMES=()
MODELS=()
EFFORTS=()
BODIES=()

for f in "${TASKFILES[@]}"; do
  [ -f "$f" ] || { echo "dispatch.sh: task file not found: $f" >&2; exit 1; }

  header="$(head -n 1 "$f")"
  case "$header" in
    [Mm][Oo][Dd][Ee][Ll]:*) ;;
    *) echo "dispatch.sh: $f: first line must be 'MODEL: <model slug>'" >&2; exit 1 ;;
  esac
  model="$(printf '%s' "$header" | sed 's/^[Mm][Oo][Dd][Ee][Ll]:[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$model" ] || { echo "dispatch.sh: $f: empty MODEL header" >&2; exit 1; }

  entry="$(printf '%s\n' "$AVAILABLE" | awk -F'\t' -v m="$model" '$1 == m { print; exit }')"
  if [ -z "$entry" ]; then
    echo "dispatch.sh: $f: '$model' is not a current Codex model for this CLI and account; choose one of:" >&2
    show_models
    exit 1
  fi
  supported="$(printf '%s' "$entry" | cut -f2)"
  effort="$(printf '%s' "$entry" | cut -f3)"

  body_from=2
  line2="$(sed -n '2p' "$f")"
  case "$line2" in
    [Ee][Ff][Ff][Oo][Rr][Tt]:*)
      effort="$(printf '%s' "$line2" | sed 's/^[Ee][Ff][Ff][Oo][Rr][Tt]:[[:space:]]*//; s/[[:space:]]*$//')"
      body_from=3
      ;;
  esac
  [ -n "$effort" ] || { echo "dispatch.sh: $f: empty EFFORT header" >&2; exit 1; }
  if [ -n "$supported" ] && ! printf ',%s,' "$supported" | grep -q ",$effort,"; then
    echo "dispatch.sh: $f: $model does not support effort '$effort' (supports: $supported)" >&2
    exit 1
  fi

  tail -n +"$body_from" "$f" | grep -q '[^[:space:]]' || {
    echo "dispatch.sh: $f: prompt body is empty" >&2; exit 1; }

  name="$(basename "$f")"
  name="${name%.prompt.md}"; name="${name%.md}"; name="${name%.txt}"

  NAMES+=("$name")
  MODELS+=("$model")
  EFFORTS+=("$effort")
  BODIES+=("$f:$body_from")
done

# --- launch ----------------------------------------------------------------
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

  "$CODEX" exec "$(cat "$promptfile")" \
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

PIDS=()
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; model="${MODELS[$i]}"; effort="${EFFORTS[$i]}"
  f="${BODIES[$i]%:*}"; body_from="${BODIES[$i]##*:}"

  promptfile="$RUN_DIR/$name.prompt"
  printf 'Working directory for this task: %s — resolve all relative paths against it.\n\n' \
    "$ROOT" > "$promptfile"
  tail -n +"$body_from" "$f" | sed '1{/^[[:space:]]*$/d;}' >> "$promptfile"

  # bounded concurrency (0 = unlimited)
  if [ "$JOBS" -gt 0 ]; then
    while [ "$(jobs -pr | wc -l)" -ge "$JOBS" ]; do sleep 1; done
  fi

  run_one "$name" "$model" "$effort" "$promptfile" &
  PIDS+=($!)
  echo "dispatched: $name  [$model/$effort]  (pid $!)"
done

echo "codex: $CODEX"
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
