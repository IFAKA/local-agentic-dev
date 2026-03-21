#!/bin/sh
# install.sh — local-agentic-dev (Frontier Edition 2026)
# curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
set -eu

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Manifest helpers
# ---------------------------------------------------------------------------
MANIFEST_DIR="$HOME/.config/opencode"
MANIFEST="$MANIFEST_DIR/.install-manifest"

manifest_set() {
  _ms_key="$1"; _ms_val="$2"
  mkdir -p "$MANIFEST_DIR"
  if [ -f "$MANIFEST" ] && grep -q "^${_ms_key}=" "$MANIFEST"; then
    _ms_tmp=$(mktemp)
    grep -v "^${_ms_key}=" "$MANIFEST" > "$_ms_tmp"
    printf '%s=%s\n' "$_ms_key" "$_ms_val" >> "$_ms_tmp"
    mv "$_ms_tmp" "$MANIFEST"
  else
    printf '%s=%s\n' "$_ms_key" "$_ms_val" >> "$MANIFEST"
  fi
}

# ---------------------------------------------------------------------------
# Modelfile fetching helper
# ---------------------------------------------------------------------------
RAW_BASE="https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

get_modelfile() {
  _gm_name="$1"; _gm_dest="$2"
  if [ -n "${REPO_DIR:-}" ] && [ -f "$REPO_DIR/modelfiles/$_gm_name" ]; then
    cp "$REPO_DIR/modelfiles/$_gm_name" "$_gm_dest"
  else
    curl -fsSL "${RAW_BASE}/modelfiles/${_gm_name}" -o "$_gm_dest"
  fi
}

REPO_DIR=""
case "$0" in */install.sh) REPO_DIR="$(cd "$(dirname "$0")" && pwd)" ;; esac

# ---------------------------------------------------------------------------
# Step 1 — Platform & RAM check
# ---------------------------------------------------------------------------
info "Checking hardware..."
[ "$(uname -s)" = "Darwin" ] || die "macOS required."
[ "$(uname -m)" = "arm64" ]  || die "Apple Silicon (arm64) required."

TOTAL_RAM=$(sysctl hw.memsize | awk '{print $2 / 1024 / 1024 / 1024}')
info "Detected ${TOTAL_RAM}GB Unified Memory."

if [ "${TOTAL_RAM%.*}" -ge 32 ]; then
  MODE="frontier"
  info "Configuring for Frontier Mode (32GB+ RAM)..."
else
  MODE="standard"
  info "Configuring for Standard Mode (<32GB RAM)..."
fi

# ---------------------------------------------------------------------------
# Step 2 & 3 — Homebrew & Ollama
# ---------------------------------------------------------------------------
command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
command -v ollama >/dev/null 2>&1 || brew install ollama

# Ensure Ollama is running
if ! curl -sf http://localhost:11434/ >/dev/null 2>&1; then
  warn "Starting Ollama..."
  ollama serve >/dev/null 2>&1 &
  sleep 5
fi

# ---------------------------------------------------------------------------
# Step 4 — Pull Base Models
# ---------------------------------------------------------------------------
if [ "$MODE" = "frontier" ]; then
  info "Pulling Q6_K high-precision models..."
  ollama pull qwen3-coder:32b-instruct-q6_K
  ollama pull deepseek-r1:32b-q6_K
else
  info "Pulling 14B models..."
  ollama pull qwen3-coder:14b
fi
ollama pull llama3.2:3b

# ---------------------------------------------------------------------------
# Step 5 — Create model variants
# ---------------------------------------------------------------------------
create_variant() {
  _cv_variant="$1"; _cv_mf="$2"
  info "Creating variant: $_cv_variant ..."
  _cv_dest="$TMP_DIR/$_cv_mf"
  get_modelfile "$_cv_mf" "$_cv_dest"
  ollama create "$_cv_variant" -f "$_cv_dest"
}

if [ "$MODE" = "frontier" ]; then
  create_variant "qwen3-coder:32b-q6_K" "qwen3-coder-32b-q6_K.modelfile"
  create_variant "deepseek-r1:32b-q6_K" "deepseek-r1-32b-q6_K.modelfile"
else
  create_variant "qwen3-coder:14b-128k" "qwen3-coder.modelfile"
fi
create_variant "llama3.2:3b-32k" "llama32.modelfile"

# ---------------------------------------------------------------------------
# Step 6 — Tools
# ---------------------------------------------------------------------------
info "Installing tools..."
command -v node >/dev/null 2>&1 || brew install node
command -v opencode >/dev/null 2>&1 || npm install -g opencode-ai
command -v aider >/dev/null 2>&1 || brew install aider

# ---------------------------------------------------------------------------
# Step 7 — Summary
# ---------------------------------------------------------------------------
printf '\n================================================\n'
printf '  local-agentic-dev: Install Complete (%s)\n' "$MODE"
printf '================================================\n\n'
if [ "$MODE" = "frontier" ]; then
  printf '  Primary model : qwen3-coder:32b-q6_K\n'
  printf '  Architect     : deepseek-r1:32b-q6_K\n'
else
  printf '  Primary model : qwen3-coder:14b-128k\n'
fi
printf '  Usage: cd /your/project && opencode\n\n'
