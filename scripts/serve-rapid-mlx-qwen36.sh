#!/bin/sh
# Serve the local Nail MLX model for Little Coder.
set -eu

DEFAULT_MODEL_DIR="$HOME/.cache/huggingface/hub/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX"
SHARED_MODEL_DIR="${NAIL_SHARED_MODEL_DIR:-/Users/Shared/LLM-Models/Nail-Qwen3.6-35B-A3B-MLX}"
if [ "${NAIL_MODEL_DIR+x}" = x ]; then
  MODEL_DIR="$NAIL_MODEL_DIR"
elif [ -d "$DEFAULT_MODEL_DIR" ]; then
  MODEL_DIR="$DEFAULT_MODEL_DIR"
else
  MODEL_DIR="$SHARED_MODEL_DIR"
fi
HOST="${RAPID_MLX_HOST:-127.0.0.1}"
PORT="${RAPID_MLX_PORT:-8000}"
MAX_TOKENS="${NAIL_MAX_TOKENS:-32768}"

exec rapid-mlx serve "$MODEL_DIR" --served-model-name "${NAIL_MODEL_ID:-nail-qwen3.6-35b-a3b}" \
  --host "$HOST" --port "$PORT" \
  --max-num-seqs 1 --max-concurrent-requests 1 \
  --enable-auto-tool-choice --tool-call-parser qwen3 \
  --no-thinking --max-tokens "$MAX_TOKENS"
