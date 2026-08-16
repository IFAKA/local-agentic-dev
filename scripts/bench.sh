#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOCAL_AGENT_REPO_ROOT="$ROOT"; export LOCAL_AGENT_REPO_ROOT
. "$ROOT/lib/config.sh"
mkdir -p "$BENCH_DIR"
MODEL_REPO="$MODEL_REPO" MODEL_ID="$MODEL_ID" BASE_URL="$BASE_URL" CONTEXT="$CONTEXT" MAX_OUTPUT="$MAX_OUTPUT" BENCH_DIR="$BENCH_DIR" PID_FILE="$PID_FILE" RAPID_MLX_BIN="$RAPID_MLX_BIN" node "$ROOT/scripts/bench.mjs"
