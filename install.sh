#!/bin/sh
# install.sh - Little Coder + Nail + Rapid-MLX local coding setup
set -eu

START_TIME=$(date +%s)
DEFAULT_MODEL_DIR="$HOME/.cache/huggingface/hub/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX"
SHARED_MODEL_DIR="${NAIL_SHARED_MODEL_DIR:-/Users/Shared/LLM-Models/Nail-Qwen3.6-35B-A3B-MLX}"
SHARED_RAPID_MLX_BIN="${NAIL_SHARED_RAPID_MLX_BIN:-/Users/Shared/LLM-Tools/rapid-mlx/bin}"
if [ "${NAIL_MODEL_DIR+x}" = x ]; then
  MODEL_DIR="$NAIL_MODEL_DIR"
elif [ -d "$DEFAULT_MODEL_DIR" ]; then
  MODEL_DIR="$DEFAULT_MODEL_DIR"
else
  MODEL_DIR="$SHARED_MODEL_DIR"
fi
# Give each user a familiar Hugging Face-style path without copying the model.
if [ "$MODEL_DIR" = "$SHARED_MODEL_DIR" ] && [ ! -e "$DEFAULT_MODEL_DIR" ] && [ ! -L "$DEFAULT_MODEL_DIR" ]; then
  mkdir -p "$(dirname "$DEFAULT_MODEL_DIR")"
  ln -s "$SHARED_MODEL_DIR" "$DEFAULT_MODEL_DIR"
fi
CONFIG_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
LITTLE_CODER_CONFIG_DIR="${LITTLE_CODER_CONFIG_DIR:-$HOME/.config/little-coder}"
LITTLE_CODER_MODELS_FILE="$LITTLE_CODER_CONFIG_DIR/models.json"
PORT="${RAPID_MLX_PORT:-8000}"
BASE_URL="${RAPID_MLX_BASE_URL:-http://127.0.0.1:$PORT/v1}"
MODEL_ID="${NAIL_MODEL_ID:-nail-qwen3.6-35b-a3b}"
CONTEXT="${NAIL_CONTEXT:-98304}"
MAX_TOKENS="${NAIL_MAX_TOKENS:-32768}"
LAUNCH_LABEL="${RAPID_MLX_LAUNCH_LABEL:-com.local-agentic-dev.rapid-mlx}"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LAUNCH_LABEL.plist"
LOG_DIR="$CONFIG_DIR/logs"
MANIFEST="$CONFIG_DIR/install-manifest"

info() { printf '[%s] %s\n' "$(( $(date +%s) - START_TIME ))s" "$*"; }
ok() { printf '[%s] ✓ %s\n' "$(( $(date +%s) - START_TIME ))s" "$*"; }
die() { printf '[%s] ✗ %s\n' "$(( $(date +%s) - START_TIME ))s" "$*" >&2; exit 1; }

rapid_mlx_works() {
  candidate="$1"
  [ -x "$candidate" ] && "$candidate" --help >/dev/null 2>&1
}

RAPID_MLX_BIN=""

case "$(uname -s):$(uname -m)" in
  Darwin:arm64) ;;
  *) die "Apple Silicon macOS is required." ;;
esac
[ -d "$MODEL_DIR" ] || die "Nail model directory not found: $MODEL_DIR"
[ -f "$MODEL_DIR/config.json" ] || die "Nail model is missing config.json: $MODEL_DIR"
[ -f "$MODEL_DIR/tokenizer.json" ] || die "Nail model is missing tokenizer.json: $MODEL_DIR"

if ! command -v node >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  info "Installing shared Homebrew Node.js"
  brew list --formula node >/dev/null 2>&1 || brew install node
  BREW_PREFIX="$(brew --prefix)"
  PATH="$BREW_PREFIX/bin:$PATH"
  export PATH
fi
command -v node >/dev/null 2>&1 || die "Node.js 22.19+ is required for Little Coder."
NODE_MAJOR="$(node --version | sed 's/^v//' | cut -d. -f1)"
[ "$NODE_MAJOR" -ge 22 ] || die "Node.js 22.19+ is required; found $(node --version)."

info "Installing/updating Rapid-MLX"
if command -v rapid-mlx >/dev/null 2>&1 && rapid_mlx_works "$(command -v rapid-mlx)"; then
  RAPID_MLX_BIN="$(command -v rapid-mlx)"
  info "Rapid-MLX already available; keeping the installed version"
elif [ -x "$SHARED_RAPID_MLX_BIN/rapid-mlx" ] && rapid_mlx_works "$SHARED_RAPID_MLX_BIN/rapid-mlx"; then
  RAPID_MLX_BIN="$SHARED_RAPID_MLX_BIN/rapid-mlx"
  info "Using shared Rapid-MLX installation"
elif command -v brew >/dev/null 2>&1 && brew list --formula rapid-mlx >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  if rapid_mlx_works "$BREW_PREFIX/bin/rapid-mlx"; then
    RAPID_MLX_BIN="$BREW_PREFIX/bin/rapid-mlx"
  fi
elif command -v brew >/dev/null 2>&1 && [ -w "$(brew --prefix)" ]; then
  brew install rapid-mlx
  BREW_PREFIX="$(brew --prefix)"
  if rapid_mlx_works "$BREW_PREFIX/bin/rapid-mlx"; then
    RAPID_MLX_BIN="$BREW_PREFIX/bin/rapid-mlx"
  fi
fi
if [ -z "$RAPID_MLX_BIN" ] && command -v uv >/dev/null 2>&1; then
  info "Installing a user-local Rapid-MLX because no usable shared installation was found"
  uv tool install --force rapid-mlx
  USER_LOCAL_BIN="$HOME/.local/bin/rapid-mlx"
  if rapid_mlx_works "$USER_LOCAL_BIN"; then
    RAPID_MLX_BIN="$USER_LOCAL_BIN"
  fi
fi
[ -n "$RAPID_MLX_BIN" ] || die "Rapid-MLX is missing or unusable. Install it with Homebrew or uv (https://github.com/raullenchai/Rapid-MLX)."
RAPID_MLX_BIN="$(cd "$(dirname "$RAPID_MLX_BIN")" && pwd)/$(basename "$RAPID_MLX_BIN")"
PATH="$(dirname "$RAPID_MLX_BIN"):$PATH"
export PATH
ok "Rapid-MLX executable validated: $RAPID_MLX_BIN"

info "Installing/updating Little Coder"
NPM_GLOBAL_PREFIX="$(npm prefix -g 2>/dev/null || true)"
if [ -n "$NPM_GLOBAL_PREFIX" ] && [ -w "$NPM_GLOBAL_PREFIX" ]; then
  npm install -g little-coder
else
  # Homebrew is shared but normally writable only by its owning admin user;
  # keep the CLI itself user-local while reusing the shared model/runtime.
  mkdir -p "$HOME/.local"
  npm install -g --prefix "$HOME/.local" little-coder
  PATH="$HOME/.local/bin:$PATH"
  export PATH
fi
command -v little-coder >/dev/null 2>&1 || die "Little Coder CLI is not on PATH."

# Pi's own update banner refers to a `pi` executable. Little Coder bundles Pi
# internally, so install a compatibility command that makes that instruction
# work without exposing the bundled dependency as a second agent installation.
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
if [ ! -e "$LOCAL_BIN/pi" ]; then
  install -m 0755 "$(dirname "$0")/scripts/pi" "$LOCAL_BIN/pi"
  ok "Installed Pi compatibility command: $LOCAL_BIN/pi"
else
  info "Keeping existing $LOCAL_BIN/pi"
fi

mkdir -p "$CONFIG_DIR" "$LITTLE_CODER_CONFIG_DIR" "$HOME/Library/LaunchAgents" "$LOG_DIR"

backup_once() {
  file="$1"
  backup="$file.pre-local-agentic-dev"
  if [ -f "$file" ] && [ ! -f "$backup" ]; then
    cp "$file" "$backup"
    ok "Backed up $file"
  fi
}
backup_once "$LITTLE_CODER_MODELS_FILE"

LITTLE_CODER_MODELS_FILE="$LITTLE_CODER_MODELS_FILE" BASE_URL="$BASE_URL" MODEL_ID="$MODEL_ID" CONTEXT="$CONTEXT" MAX_TOKENS="$MAX_TOKENS" node <<'EOF_NODE'
const fs = require('fs');
const path = require('path');
const file = process.env.LITTLE_CODER_MODELS_FILE || path.join(process.env.HOME, '.config/little-coder/models.json');
fs.mkdirSync(path.dirname(file), { recursive: true });
const config = {
  // Pi/Little Coder accepts a thinking suffix on the default model selector.
  // Keep reasoning available, but start new sessions with it disabled.
  default: `rapid-mlx/${process.env.MODEL_ID}:off`,
  providers: {
    'rapid-mlx': {
      api: 'openai-completions',
      baseUrl: process.env.BASE_URL,
      apiKey: 'not-needed',
      models: [{
        id: process.env.MODEL_ID,
        name: 'Nail Qwen3.6-35B-A3B (local MLX)',
        reasoning: true,
        input: ['text', 'image'],
        contextWindow: Number(process.env.CONTEXT),
        maxTokens: Number(process.env.MAX_TOKENS),
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
      }]
    }
  }
};
fs.writeFileSync(file, JSON.stringify(config, null, 2) + '\n');
EOF_NODE
ok "Little Coder provider configured: rapid-mlx/$MODEL_ID"

# Little Coder v1.14 currently forces interactive launches to medium unless
# --thinking is present on the command line. Keep the local setup off by
# default while preserving explicit --thinking and --model ...:level choices.
ZSHRC="$HOME/.zshrc"
ZSH_MARKER="# local-agentic-dev: Little Coder thinking default"
if [ ! -f "$ZSHRC" ] || ! grep -Fq "$ZSH_MARKER" "$ZSHRC"; then
  cat >> "$ZSHRC" <<'EOF_ZSH'

# local-agentic-dev: Little Coder thinking default
little-coder() {
  local arg previous=""
  for arg in "$@"; do
    if [[ "$arg" == "--thinking" || ( "$previous" == "--model" && "$arg" == *:* ) ]]; then
      command little-coder "$@"
      return
    fi
    previous="$arg"
  done
  command little-coder --thinking off "$@"
}
EOF_ZSH
  ok "Little Coder interactive default: thinking off"
else
  info "Little Coder interactive default already configured or ~/.zshrc is absent"
fi

cat > "$LAUNCH_AGENT" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LAUNCH_LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$RAPID_MLX_BIN</string><string>serve</string><string>$MODEL_DIR</string><string>--served-model-name</string><string>$MODEL_ID</string>
    <string>--host</string><string>127.0.0.1</string><string>--port</string><string>$PORT</string>
    <string>--max-num-seqs</string><string>1</string><string>--max-concurrent-requests</string><string>1</string>
    <string>--enable-auto-tool-choice</string><string>--tool-call-parser</string><string>qwen3</string>
    <string>--no-thinking</string><string>--max-tokens</string><string>$MAX_TOKENS</string>
  </array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$LOG_DIR/rapid-mlx.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/rapid-mlx.err.log</string>
</dict></plist>
EOF_PLIST

cat > "$MANIFEST" <<EOF_MANIFEST
harness=little-coder-nail-rapid-mlx
little_coder_models=$LITTLE_CODER_MODELS_FILE
pi_compat=$LOCAL_BIN/pi
rapid_mlx_launch_agent=$LAUNCH_AGENT
rapid_mlx_launch_label=$LAUNCH_LABEL
rapid_mlx_bin=$RAPID_MLX_BIN
rapid_mlx_port=$PORT
rapid_mlx_base_url=$BASE_URL
nail_model_dir=$MODEL_DIR
nail_model_id=$MODEL_ID
EOF_MANIFEST

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  die "Port $PORT is already in use. Set RAPID_MLX_PORT and RAPID_MLX_BASE_URL, then rerun."
fi
if launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"; then
  launchctl kickstart -k "gui/$(id -u)/$LAUNCH_LABEL" >/dev/null 2>&1 || true
else
  printf '%s\n' "Warning: macOS did not register the LaunchAgent in this session; configuration was still written." >&2
  printf '%s\n' "Start it manually with: scripts/serve-rapid-mlx-qwen36.sh (or inspect launchctl/bootstrap permissions)." >&2
  exit 0
fi

info "Waiting for Rapid-MLX to load Nail (up to 90 seconds)"
attempt=0
while [ "$attempt" -lt 90 ]; do
  if curl -fsS --max-time 2 "$BASE_URL/models" >/dev/null 2>&1; then
    ok "Rapid-MLX endpoint ready: $BASE_URL"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -lt 90 ] || die "Rapid-MLX did not become ready. Inspect $LOG_DIR/rapid-mlx.err.log"

printf '\nSetup complete.\n  Agent: little-coder\n  Model: %s\n  Endpoint: %s\n  LaunchAgent: %s\n\nRun: little-coder\n' "$MODEL_ID" "$BASE_URL" "$LAUNCH_AGENT"
