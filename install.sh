#!/bin/sh
# install.sh — Pi agent local setup for Ollama + OpenCode + Aider
# curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
set -eu

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

RAW_BASE="https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main"
SHARED_MODELS_DIR="${OLLAMA_MODELS_DIR:-/Users/Shared/ollama-models}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
PI_AGENT_MODEL="${PI_AGENT_MODEL:-qwen3.6-27b-reasoning:27b-q6}"
PI_AGENT_UPSTREAM_MODEL="${PI_AGENT_UPSTREAM_MODEL:-batiai/qwen3.6-27b:q6}"
PI_AGENT_CONTEXT="${PI_AGENT_CONTEXT:-32768}"
PI_AGENT_SMALL_MODEL="${PI_AGENT_SMALL_MODEL:-llama3.2:3b}"

MANIFEST_DIR="$HOME/.config/local-agentic-dev"
MANIFEST="$MANIFEST_DIR/install-manifest"
OPENCODE_DIR="$HOME/.config/opencode"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

REPO_DIR=""
case "$0" in */install.sh) REPO_DIR="$(cd "$(dirname "$0")" && pwd)" ;; esac

manifest_set() {
  _key="$1"; _value="$2"
  mkdir -p "$MANIFEST_DIR"
  if [ -f "$MANIFEST" ] && grep -q "^${_key}=" "$MANIFEST"; then
    _tmp=$(mktemp)
    grep -v "^${_key}=" "$MANIFEST" > "$_tmp"
    printf '%s=%s\n' "$_key" "$_value" >> "$_tmp"
    mv "$_tmp" "$MANIFEST"
  else
    printf '%s=%s\n' "$_key" "$_value" >> "$MANIFEST"
  fi
}

fetch_config() {
  _name="$1"; _dest="$2"
  if [ -n "$REPO_DIR" ] && [ -f "$REPO_DIR/config/$_name" ]; then
    cp "$REPO_DIR/config/$_name" "$_dest"
  else
    curl -fsSL "$RAW_BASE/config/$_name" -o "$_dest"
  fi
}

install_template() {
  _src="$1"; _dest="$2"
  _tmp="$TMP_DIR/$(basename "$_dest").tmp"
  fetch_config "$_src" "$_tmp"
  sed \
    -e "s|__PI_AGENT_MODEL__|$PI_AGENT_MODEL|g" \
    -e "s|__PI_AGENT_SMALL_MODEL__|$PI_AGENT_SMALL_MODEL|g" \
    -e "s|__PI_AGENT_CONTEXT__|$PI_AGENT_CONTEXT|g" \
    "$_tmp" > "$_dest"
}

model_exists() {
  ollama list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

create_pi_agent_model() {
  _modelfile="$TMP_DIR/pi-agent.Modelfile"
  cat > "$_modelfile" <<EOF
FROM $PI_AGENT_UPSTREAM_MODEL
PARAMETER num_ctx $PI_AGENT_CONTEXT
PARAMETER temperature 0.6
PARAMETER top_k 20
PARAMETER top_p 0.95
PARAMETER repeat_penalty 1.05
PARAMETER min_p 0

SYSTEM "You are a reasoning-focused local coding agent. Be concise and direct. Think deeply before answering complex software engineering questions. Use tools when they materially improve correctness."
EOF
  ollama create "$PI_AGENT_MODEL" -f "$_modelfile"
}

info "Checking platform..."
[ "$(uname -s)" = "Darwin" ] || die "macOS required."
[ "$(uname -m)" = "arm64" ] || die "Apple Silicon required."

TOTAL_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || printf '0')
TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))
info "Detected ${TOTAL_RAM_GB}GB unified memory."
if [ "$TOTAL_RAM_GB" -lt 32 ]; then
  warn "This setup targets 32GB+ Macs. Your model may be slow or fail under memory pressure."
fi

info "Configuring shared Ollama model cache: $SHARED_MODELS_DIR"
mkdir -p "$SHARED_MODELS_DIR"
chmod 775 "$SHARED_MODELS_DIR" 2>/dev/null || true

if [ -d "$HOME/.ollama/models" ] && [ "$HOME/.ollama/models" != "$SHARED_MODELS_DIR" ]; then
  if [ ! -d "$SHARED_MODELS_DIR/blobs" ] && [ ! -d "$SHARED_MODELS_DIR/manifests" ]; then
    info "Copying existing Ollama models from ~/.ollama/models into the shared cache..."
    cp -R "$HOME/.ollama/models/." "$SHARED_MODELS_DIR/"
    chmod -R g+rwX "$SHARED_MODELS_DIR" 2>/dev/null || true
    ok "Copied existing model cache."
  else
    info "Shared cache already contains Ollama model data."
  fi
fi

launchctl setenv OLLAMA_MODELS "$SHARED_MODELS_DIR" 2>/dev/null || true
export OLLAMA_MODELS="$SHARED_MODELS_DIR"
manifest_set ollama_models_dir "$SHARED_MODELS_DIR"
manifest_set pi_agent_model "$PI_AGENT_MODEL"
manifest_set pi_agent_context "$PI_AGENT_CONTEXT"

command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
command -v ollama >/dev/null 2>&1 || brew install ollama

if ! curl -sf "$OLLAMA_HOST/" >/dev/null 2>&1; then
  info "Starting Ollama with shared model cache..."
  OLLAMA_MODELS="$SHARED_MODELS_DIR" ollama serve >/dev/null 2>&1 &
  _timeout=20
  while ! curl -sf "$OLLAMA_HOST/" >/dev/null 2>&1; do
    sleep 1
    _timeout=$((_timeout - 1))
    [ "$_timeout" -gt 0 ] || die "Ollama did not start within 20 seconds."
  done
else
  warn "Ollama is already running. Restart Ollama after install so it uses $SHARED_MODELS_DIR."
fi

info "Checking Pi agent model: $PI_AGENT_MODEL"
if model_exists "$PI_AGENT_MODEL"; then
  ok "$PI_AGENT_MODEL is available."
elif model_exists "$PI_AGENT_UPSTREAM_MODEL"; then
  info "Creating $PI_AGENT_MODEL from existing upstream model $PI_AGENT_UPSTREAM_MODEL ..."
  create_pi_agent_model
elif [ -n "$PI_AGENT_UPSTREAM_MODEL" ]; then
  warn "$PI_AGENT_MODEL not found. Pulling upstream model once: $PI_AGENT_UPSTREAM_MODEL"
  ollama pull "$PI_AGENT_UPSTREAM_MODEL"
  create_pi_agent_model
else
  die "$PI_AGENT_MODEL was not found and PI_AGENT_UPSTREAM_MODEL is empty."
fi

if ! model_exists "$PI_AGENT_SMALL_MODEL"; then
  info "Pulling small helper model: $PI_AGENT_SMALL_MODEL"
  ollama pull "$PI_AGENT_SMALL_MODEL"
fi

info "Installing tools..."
command -v node >/dev/null 2>&1 || brew install node
if command -v opencode >/dev/null 2>&1; then
  manifest_set installed_opencode false
else
  npm install -g opencode-ai
  manifest_set installed_opencode true
fi
command -v aider >/dev/null 2>&1 || brew install aider

info "Installing OpenCode config..."
mkdir -p "$OPENCODE_DIR"
OPENCODE_CFG="$OPENCODE_DIR/opencode.json"
if [ -f "$OPENCODE_CFG" ] && [ ! -f "$OPENCODE_CFG.pre-local-agentic-dev" ]; then
  cp "$OPENCODE_CFG" "$OPENCODE_CFG.pre-local-agentic-dev"
  ok "Backed up existing OpenCode config."
fi
install_template "opencode.json" "$OPENCODE_CFG"
manifest_set installed_opencode_config true

info "Installing Aider config..."
AIDER_CFG="$HOME/.aider.conf.yml"
if [ -f "$AIDER_CFG" ] && [ ! -f "$AIDER_CFG.pre-local-agentic-dev" ]; then
  cp "$AIDER_CFG" "$AIDER_CFG.pre-local-agentic-dev"
  ok "Backed up existing Aider config."
fi
install_template "aider.conf.yml" "$AIDER_CFG"
manifest_set installed_aider_config true

printf '\n================================================\n'
printf '  Pi Agent Local Setup Complete\n'
printf '================================================\n\n'
printf '  Model cache : %s\n' "$SHARED_MODELS_DIR"
printf '  Main model  : %s\n' "$PI_AGENT_MODEL"
printf '  Context     : %s\n' "$PI_AGENT_CONTEXT"
printf '  Small model : %s\n\n' "$PI_AGENT_SMALL_MODEL"
printf '  Restart Ollama if it was already running before this install.\n'
printf '  Usage: cd /your/project && opencode\n\n'
