#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
SANDBOX_HOME="$RESULTS_DIR/sandbox-home"
WORKSPACES_DIR="$RESULTS_DIR/benchmark-workspaces"
AGENT="opencode"
MODEL="qwen3.6:35b-a3b-nvfp4"
readonly MODEL
PROMPT="Explain the repository purpose in three concise bullets using only local context."
TIMEOUT_SECONDS="${LOCAL_AI_WORKSTATION_BENCHMARK_TIMEOUT:-120}"
EXECUTE="${LOCAL_AI_WORKSTATION_BENCHMARK_EXECUTE:-0}"

usage() {
  cat <<'USAGE'
Usage: benchmark-agent.sh [--execute] [--agent opencode] [--prompt TEXT]

Dry-run is the default. It writes a repo-local benchmark plan/result under
  docs/local-ai-workstation/results/
with MEASURED_RESULT_PENDING placeholders and does not invoke agent CLIs.

Measured execution requires --execute or LOCAL_AI_WORKSTATION_BENCHMARK_EXECUTE=1.
Execution uses a repo-local sandbox HOME/XDG tree and runs from a copied benchmark
workspace under docs/local-ai-workstation/results/ so user home config and the
original repository are not mutated by default.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE="1" ;;
    --agent) shift; AGENT="${1:-}" ;;
    --model) echo "Unsupported argument: --model. LAD benchmark is locked to qwen3.6:35b-a3b-nvfp4." >&2; exit 2 ;;
    --prompt) shift; PROMPT="${1:-}" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$AGENT" in
  opencode) ;;
  *) echo "Unsupported agent: $AGENT. Only OpenCode is supported." >&2; exit 2 ;;
esac

case "$EXECUTE" in
  1|true|TRUE|yes|YES) EXECUTE="1" ;;
  0|false|FALSE|no|NO|"") EXECUTE="0" ;;
  *) echo "Invalid execute value: $EXECUTE" >&2; exit 2 ;;
esac

mkdir -p "$RESULTS_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_file="$RESULTS_DIR/benchmark-$AGENT-$stamp.md"
raw_file="$RESULTS_DIR/benchmark-$AGENT-$stamp.raw.txt"
workspace_dir="$WORKSPACES_DIR/$AGENT-$stamp"
status="dry-run-plan"
exit_code="MEASURED_RESULT_PENDING"
elapsed_seconds="MEASURED_RESULT_PENDING"
command_display="MEASURED_RESULT_PENDING"
started_epoch="MEASURED_RESULT_PENDING"
ended_epoch="MEASURED_RESULT_PENDING"

opencode_model() {
  case "$MODEL" in
    ollama/*) printf '%s\n' "$MODEL" ;;
    *) printf 'ollama/%s\n' "$MODEL" ;;
  esac
}

agent_command_display() {
  printf 'opencode run --model %q %q\n' "$(opencode_model)" "$PROMPT"
}

run_with_optional_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SECONDS" "$@"
  else
    "$@"
  fi
}

prepare_workspace() {
  mkdir -p "$WORKSPACES_DIR"
  rm -rf "$workspace_dir"
  mkdir -p "$workspace_dir"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude '.git/' \
      --exclude 'docs/local-ai-workstation/.lad/' \
      --exclude 'docs/local-ai-workstation/sessions/' \
      --exclude 'docs/local-ai-workstation/results/' \
      "$SCRIPT_DIR/../../" "$workspace_dir/"
  else
    (cd "$SCRIPT_DIR/../.." && tar \
      --exclude './.git' \
      --exclude './docs/local-ai-workstation/.lad' \
      --exclude './docs/local-ai-workstation/sessions' \
      --exclude './docs/local-ai-workstation/results' \
      -cf - .) | (cd "$workspace_dir" && tar -xf -)
  fi

  if command -v git >/dev/null 2>&1; then
    (cd "$workspace_dir" && git init -q && git add . && git commit -qm "benchmark workspace snapshot" >/dev/null 2>&1) || true
  fi
}

prepare_sandbox_config() {
  mkdir -p \
    "$SANDBOX_HOME/.config/opencode" \
    "$SANDBOX_HOME/.cache" \
    "$SANDBOX_HOME/.local/state" \
    "$SANDBOX_HOME/.local/share"

  if [[ -f "$HOME/.config/opencode/opencode.json" ]]; then
    cp "$HOME/.config/opencode/opencode.json" "$SANDBOX_HOME/.config/opencode/opencode.json"
  fi
}

run_agent() {
  if ! command -v opencode >/dev/null 2>&1; then
    echo "opencode not found on PATH"
    return 127
  fi
  run_with_optional_timeout opencode run --model "$(opencode_model)" "$PROMPT"
}
write_report() {
  cat > "$result_file" <<REPORT
# Local AI Workstation Benchmark Result

Generated: $stamp UTC
Agent: opencode
Model: $MODEL
Default context target: 64K when supported
Status: $status
Exit code: $exit_code
Elapsed wall seconds: $elapsed_seconds
Raw output: $(basename "$raw_file")
Execution mode: $(if [[ "$EXECUTE" == "1" ]]; then echo "measured --execute"; else echo "dry-run plan"; fi)
Sandbox HOME: $(if [[ "$EXECUTE" == "1" ]]; then echo "$SANDBOX_HOME"; else echo "MEASURED_RESULT_PENDING"; fi)
Benchmark workspace: $(if [[ "$EXECUTE" == "1" ]]; then echo "$workspace_dir"; else echo "MEASURED_RESULT_PENDING"; fi)

## Prompt

~~~text
$PROMPT
~~~

## Command

~~~bash
$command_display
~~~

## Safety policy

Dry-run is the default. Measured execution requires --execute or LOCAL_AI_WORKSTATION_BENCHMARK_EXECUTE=1.
When measured execution is enabled, HOME, XDG_CONFIG_HOME, XDG_CACHE_HOME, XDG_STATE_HOME, and XDG_DATA_HOME are redirected under docs/local-ai-workstation/results/sandbox-home, and OpenCode runs from a copied benchmark workspace under docs/local-ai-workstation/results/benchmark-workspaces.
If GNU timeout is unavailable on macOS, LOCAL_AI_WORKSTATION_BENCHMARK_TIMEOUT is documented but not enforced by this script.

## Metrics policy

Only measured values are recorded. Missing, unsupported, skipped, or failed commands are evidence and must not be converted into synthetic success metrics.

## Placeholder fields for later analysis

- Token throughput: MEASURED_RESULT_PENDING
- Peak memory pressure: MEASURED_RESULT_PENDING
- Task success classification: MEASURED_RESULT_PENDING
- Notes from human review: MEASURED_RESULT_PENDING
REPORT
}

command_display="$(agent_command_display)"

if [[ "$EXECUTE" != "1" ]]; then
  cat > "$raw_file" <<RAW
DRY RUN ONLY: agent command was not executed.
Planned command:
$command_display

Run with --execute or LOCAL_AI_WORKSTATION_BENCHMARK_EXECUTE=1 to collect measured output.
RAW
  write_report
  echo "Wrote dry-run benchmark plan: $result_file"
  echo "Wrote dry-run raw output: $raw_file"
  exit 0
fi

prepare_workspace
prepare_sandbox_config

started_epoch="$(date +%s)"
set +e
(
  cd "$workspace_dir" || exit 1
  export HOME="$SANDBOX_HOME"
  export XDG_CONFIG_HOME="$SANDBOX_HOME/.config"
  export XDG_CACHE_HOME="$SANDBOX_HOME/.cache"
  export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
  export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
  export GIT_CEILING_DIRECTORIES="$WORKSPACES_DIR"
  run_agent
) > "$raw_file" 2>&1
exit_code="$?"
set -e
ended_epoch="$(date +%s)"
elapsed_seconds="$((ended_epoch - started_epoch))"

if [[ "$exit_code" == "0" ]]; then
  status="completed"
else
  status="failed-or-unavailable"
fi

write_report

echo "Wrote benchmark result: $result_file"
