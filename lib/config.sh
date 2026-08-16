#!/bin/sh
set -eu

CONFIG_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
STATE_DIR="$CONFIG_DIR/state"
LOG_DIR="$CONFIG_DIR/logs"
PID_FILE="$STATE_DIR/rapid-mlx.pid"
BENCH_DIR="$CONFIG_DIR/benchmarks"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
if [ -z "${LOCAL_AGENT_REPO_ROOT:-}" ]; then
  LOCAL_AGENT_REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fi
CONFIG_FILE="$LOCAL_AGENT_REPO_ROOT/config/local-agent.conf"
[ -f "$CONFIG_FILE" ] || { printf '%s\n' "Missing canonical config: $CONFIG_FILE" >&2; exit 1; }
. "$CONFIG_FILE"
BASE_URL="${RAPID_MLX_BASE_URL:-http://${HOST}:${PORT}/v1}"
if [ -z "${RAPID_MLX_BIN:-}" ] && command -v brew >/dev/null 2>&1; then
  brew_rapid="$(brew --prefix rapid-mlx 2>/dev/null || true)/bin/rapid-mlx"
  [ -x "$brew_rapid" ] && RAPID_MLX_BIN="$brew_rapid"
fi
RAPID_MLX_BIN="${RAPID_MLX_BIN:-$(command -v rapid-mlx 2>/dev/null || true)}"
