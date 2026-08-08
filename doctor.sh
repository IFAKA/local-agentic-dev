#!/bin/sh
# doctor.sh - classify Pi/Rapid-MLX workstation readiness without changing state
set -u

PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
CONFIG_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
BASE_URL="${PI_RAPID_BASE_URL:-http://127.0.0.1:${PI_RAPID_PORT:-8000}/v1}"
MODEL="${PI_RAPID_MODEL:-mlx-community/Qwen3.6-35B-A3B-nvfp4}"
MIN_FREE_GB="${PI_MIN_FREE_GB:-20}"
MIN_MEMORY_GB="${PI_MIN_MEMORY_GB:-40}"
REQUIRED_PI="${PI_REQUIRED_VERSION:-0.84.1}"
failures=0

pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; failures=$((failures + 1)); }

printf 'Pi + Rapid-MLX doctor\nEndpoint: %s\nModel: %s\n\n' "$BASE_URL" "$MODEL"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] && pass "Hardware: Apple Silicon macOS" || fail "Hardware: Apple Silicon macOS is required"
mem="$(sysctl -n hw.memsize 2>/dev/null || printf 0)"
min_mem=$((MIN_MEMORY_GB * 1024 * 1024 * 1024))
[ "$mem" -ge "$min_mem" ] && pass "Hardware: memory is at least ${MIN_MEMORY_GB} GB" || fail "Hardware: memory is below ${MIN_MEMORY_GB} GB"
free_kb="$(df -Pk "$CONFIG_DIR" 2>/dev/null | awk 'NR==2 {print $4}')"
min_kb=$((MIN_FREE_GB * 1024 * 1024))
[ "${free_kb:-0}" -ge "$min_kb" ] && pass "Disk: $((free_kb / 1024 / 1024)) GB free" || fail "Disk: only $(( ${free_kb:-0} / 1024 / 1024 )) GB free; ${MIN_FREE_GB} GB required"

if command -v pi >/dev/null 2>&1; then
  pi_version="$(pi --version 2>/dev/null | head -1 | tr -d v)"
  [ "$pi_version" = "$REQUIRED_PI" ] && pass "Pi: version $pi_version" || warn "Pi: stale version ${pi_version:-unknown}; required $REQUIRED_PI"
else
  fail "Pi: CLI not found"
fi
command -v rapid-mlx >/dev/null 2>&1 && pass "Rapid-MLX: CLI available ($(rapid-mlx --version 2>/dev/null | head -1))" || fail "Rapid-MLX: CLI not found"

model_file="${TMPDIR:-/tmp}/local-agentic-dev-models.$$"
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 3 "$BASE_URL/models" >"$model_file" 2>/dev/null; then
  if grep -Fq "$MODEL" "$model_file"; then pass "Server: endpoint ready and model advertised"; else warn "Server: endpoint ready but model id was not advertised"; fi
else
  fail "Server: Rapid-MLX endpoint is not ready"
fi
rm -f "$model_file"

if [ -f "$CONFIG_DIR/logs/rapid-mlx.err.log" ] && grep -Eiq 'warning|diagnostic|not found.*optional|deprecated' "$CONFIG_DIR/logs/rapid-mlx.err.log"; then
  warn "Rapid-MLX diagnostics: warnings found in rapid-mlx.err.log; inspect the log (not classified as hardware failure)"
fi
if [ -f "$CONFIG_DIR/install-manifest" ]; then pass "Configuration: install manifest present"; else warn "Configuration: installer has not completed"; fi
exit "$failures"
