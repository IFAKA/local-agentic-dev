#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
report_file="$RESULTS_DIR/versions-$stamp.md"

capture_version() {
  local label="$1"
  shift
  local executable="$1"
  shift

  {
    echo "### $label"
    echo
    if command -v "$executable" >/dev/null 2>&1; then
      echo '- Status: found'
      echo '- Path:' "$(command -v "$executable")"
      echo
      echo '```text'
      set +e
      output="$("$executable" "$@" 2>&1)"
      command_status="$?"
      set -e
      printf '%s\n' "$output" | tr -d '\r'
      if [[ "$command_status" != "0" ]]; then
        echo "Command exited non-zero: $command_status"
      fi
      echo '```'
    else
      echo '- Status: not found on PATH'
      echo '- Version: MEASURED_RESULT_PENDING'
    fi
    echo
  } >> "$report_file"
}

{
  cat <<REPORT
# Local AI Workstation Version Report

Generated: $stamp UTC
Host target: Apple M4 Pro 48 GB
Model: qwen3.6:35b-a3b-nvfp4
Agent: OpenCode
Default context target: 64K when supported

REPORT
} > "$report_file"

capture_version "macOS" sw_vers
capture_version "Ollama" ollama --version
capture_version "OpenCode" opencode --version
capture_version "Ghostty" ghostty --version
capture_version "tmux" tmux -V
capture_version "zsh" zsh --version
capture_version "Neovim" nvim --version

{
  echo '## Ollama local models'
  echo
  if command -v ollama >/dev/null 2>&1; then
    echo '```text'
    ollama list 2>&1 || echo "Command exited non-zero: $?"
    echo '```'
  else
    echo 'MEASURED_RESULT_PENDING: ollama not found on PATH.'
  fi
  echo
  echo '## Notes'
  echo
  echo '- This report is repo-local evidence only.'
  echo '- Missing tools are recorded as missing; no values are fabricated.'
} >> "$report_file"

echo "Wrote version report: $report_file"
