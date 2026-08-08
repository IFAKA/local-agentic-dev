#!/bin/sh
# Serve the sole Rapid-MLX Qwen3.6 35B NVFP4 runtime for Pi.
set -eu

RAPID_MODEL="${RAPID_MODEL:-mlx-community/Qwen3.6-35B-A3B-nvfp4}"
RAPID_HOST="${RAPID_HOST:-127.0.0.1}"
RAPID_PORT="${RAPID_PORT:-8000}"
RAPID_MAX_TOKENS="${RAPID_MAX_TOKENS:-12288}"

exec rapid-mlx serve "$RAPID_MODEL" \
  --host "$RAPID_HOST" \
  --port "$RAPID_PORT" \
  --max-num-seqs 1 \
  --max-concurrent-requests 1 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3 \
  --no-thinking \
  --max-tokens "$RAPID_MAX_TOKENS"
