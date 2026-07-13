#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
APPLY=0
REASON="unspecified"

usage() {
  cat <<'USAGE'
Usage: rollback.sh [--reason TEXT] [--apply]

Creates a repo-local rollback plan. Dry-run by default.
Set LOCAL_AI_WORKSTATION_ROLLBACK_APPLY=1 or pass --apply to write the plan file.
No external rollback commands are executed by this script.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --reason) shift; REASON="${1:-}" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${LOCAL_AI_WORKSTATION_ROLLBACK_APPLY:-0}" == "1" ]]; then
  APPLY=1
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
plan_file="$RESULTS_DIR/rollback-plan-$stamp.md"
latest_report="none"
if [[ -d "$RESULTS_DIR" ]]; then
  latest_report="$(find "$RESULTS_DIR" -maxdepth 1 -type f | sort | tail -n 1 || true)"
  [[ -n "$latest_report" ]] || latest_report="none"
fi

plan_content() {
  cat <<PLAN
# Local AI Workstation Rollback Plan

Generated: $stamp UTC
Mode: $([[ "$APPLY" == "1" ]] && echo "apply repo-local plan write" || echo "dry-run")
Reason: $REASON
Latest repo-local report seen: $latest_report

## Scope

Rollback planning only. This script does not mutate Ollama, OpenCode, shell profiles, package managers, or user home configuration.

## Operator investigation

- Identify the last known good measured benchmark result.
- Compare model versions, agent versions, and context settings.
- Confirm whether the regression affects the OpenCode path.

## Operator-approved external commands

Review before running manually. Exact downgrade or removal commands depend on how each tool was installed.

\`\`\`bash
# Examples only; validate locally before execution.
ollama list
opencode --version
# If needed, run the tool-specific rollback command approved by the operator.
\`\`\`

## Measurement placeholders

- Last known good version report: MEASURED_RESULT_PENDING
- Post-rollback OpenCode benchmark: MEASURED_RESULT_PENDING
PLAN
}

if [[ "$APPLY" != "1" ]]; then
  echo "Dry-run: would write $plan_file"
  echo
  plan_content
  exit 0
fi

mkdir -p "$RESULTS_DIR"
plan_content > "$plan_file"
echo "Wrote repo-local rollback plan: $plan_file"
