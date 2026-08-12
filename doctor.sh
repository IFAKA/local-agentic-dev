#!/bin/sh
# doctor.sh - read-only Little Coder + Nail + Rapid-MLX readiness check
set -u

MODEL_DIR="${NAIL_MODEL_DIR:-$HOME/.cache/huggingface/hub/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX}"
CONFIG_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
BASE_URL="${RAPID_MLX_BASE_URL:-http://127.0.0.1:${RAPID_MLX_PORT:-8000}/v1}"
MODEL_ID="${NAIL_MODEL_ID:-nail-qwen3.6-35b-a3b}"
failures=0
pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; failures=$((failures + 1)); }

printf 'Little Coder + Nail + Rapid-MLX doctor\nEndpoint: %s\nModel: %s\n\n' "$BASE_URL" "$MODEL_DIR"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] && pass "Hardware: Apple Silicon macOS" || fail "Hardware: Apple Silicon macOS is required"
[ -d "$MODEL_DIR" ] && [ -f "$MODEL_DIR/config.json" ] && [ -f "$MODEL_DIR/tokenizer.json" ] && pass "Nail: local model files present" || fail "Nail: local model directory is incomplete"
command -v node >/dev/null 2>&1 && pass "Node.js: $(node --version)" || fail "Node.js: CLI not found"
command -v little-coder >/dev/null 2>&1 && pass "Little Coder: CLI available" || fail "Little Coder: CLI not found"
command -v rapid-mlx >/dev/null 2>&1 && pass "Rapid-MLX: CLI available" || fail "Rapid-MLX: CLI not found"

models_file="${LITTLE_CODER_MODELS_FILE:-$HOME/.config/little-coder/models.json}"
[ -f "$models_file" ] && grep -Fq "rapid-mlx" "$models_file" && pass "Configuration: Little Coder provider present" || warn "Configuration: Little Coder provider is not configured"
if curl -fsS --max-time 3 "$BASE_URL/models" >/tmp/local-agentic-dev-models.$$ 2>/dev/null; then
  grep -Fq "$MODEL_ID" /tmp/local-agentic-dev-models.$$ && pass "Server: Nail model advertised" || warn "Server: endpoint ready; model id differs from configured handle"
else
  warn "Server: Rapid-MLX endpoint is not ready"
fi
rm -f /tmp/local-agentic-dev-models.$$
[ -f "$CONFIG_DIR/install-manifest" ] && pass "Configuration: install manifest present" || warn "Configuration: installer has not completed"
exit "$failures"
