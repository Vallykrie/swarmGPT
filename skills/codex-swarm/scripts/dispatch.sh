#!/usr/bin/env bash
# dispatch.sh — launch a swarm of parallel `codex exec` (Codex CLI / GPT) jobs.
#
# Each TASKFILE is a subtask prompt file. Its first line must be a model
# header; an EFFORT header may follow:
#
#     MODEL: gpt-6-sol
#     EFFORT: medium
#
#     <the subtask prompt, any number of lines>
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
#
# Exit code: 0 if every job succeeded, 1 otherwise.

set -u

MODE="auto"
TIMEOUT="20m"
JOBS=0
LOG_ROOT=".codex-swarm/logs"
TASKFILES=()

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
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
    -h|--help)  usage 0 ;;
    -*)         echo "dispatch.sh: unknown option: $1" >&2; usage 1 ;;
    *)          TASKFILES+=("$1") ;;
  esac
  shift
done

[ "${#TASKFILES[@]}" -gt 0 ] || { echo "dispatch.sh: no task files given" >&2; usage 1; }

command -v codex >/dev/null 2>&1 || {
  echo "dispatch.sh: 'codex' not found on PATH — install the Codex CLI first:" >&2
  echo "  npm install -g @openai/codex   (or: brew install codex)" >&2
  exit 1
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
    *) echo "dispatch.sh: $f: first line must be 'MODEL: <codex model slug>'" >&2; exit 1 ;;
  esac
  model="$(printf '%s' "$header" | sed 's/^[Mm][Oo][Dd][Ee][Ll]:[[:space:]]*//')"
  [ -n "$model" ] || { echo "dispatch.sh: $f: empty MODEL header" >&2; exit 1; }

  effort="medium"
  body_from=2
  line2="$(sed -n '2p' "$f")"
  case "$line2" in
    [Ee][Ff][Ff][Oo][Rr][Tt]:*)
      effort="$(printf '%s' "$line2" | sed 's/^[Ee][Ff][Ff][Oo][Rr][Tt]:[[:space:]]*//')"
      body_from=3
      ;;
  esac
  [ -n "$effort" ] || { echo "dispatch.sh: $f: empty EFFORT header" >&2; exit 1; }

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
  echo "dispatched: $name  [$model/$effort]  (pid $!)"
done

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
