#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
APPLY=0

usage() {
  cat <<'USAGE'
Usage: update.sh [--apply]

Creates a repo-local local-AI-workstation update plan. Dry-run by default.
Set LOCAL_AI_WORKSTATION_UPDATE_APPLY=1 or pass --apply to write the plan file.
No external update commands are executed by this script.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${LOCAL_AI_WORKSTATION_UPDATE_APPLY:-0}" == "1" ]]; then
  APPLY=1
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
plan_file="$RESULTS_DIR/update-plan-$stamp.md"

plan_content() {
  cat <<PLAN
# Local AI Workstation Update Plan

Generated: $stamp UTC
Mode: $([[ "$APPLY" == "1" ]] && echo "apply repo-local plan write" || echo "dry-run")

## Scope

- Model: qwen3.6:35b-a3b-nvfp4
- Agent: OpenCode
- Default context: 64K where supported

## Repo-local actions

- Write this plan under docs/local-ai-workstation/results/ only when explicitly applied.
- Re-run collect-versions.sh after any operator-managed external update.
- Re-run benchmark-agent.sh and record measured results. Do not invent metrics.

## Operator-approved external commands

Review before running manually. This script does not execute them.

\`\`\`bash
# Example only; confirm exact commands for your installed tools first.
ollama pull qwen3.6:35b-a3b-nvfp4
opencode --version
\`\`\`

## Measurement placeholders

- Version report after update: MEASURED_RESULT_PENDING
- OpenCode benchmark after update: MEASURED_RESULT_PENDING
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
echo "Wrote repo-local update plan: $plan_file"
