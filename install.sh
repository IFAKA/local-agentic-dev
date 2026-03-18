#!/bin/sh
# install.sh — local-agentic-dev
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

# manifest_set KEY VALUE — writes key=value, replacing existing key if present
manifest_set() {
  _ms_key="$1"
  _ms_val="$2"
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

# manifest_get KEY — prints the value, or empty string
manifest_get() {
  if [ -f "$MANIFEST" ]; then
    grep "^${1}=" "$MANIFEST" 2>/dev/null | cut -d= -f2- || true
  fi
}

# ---------------------------------------------------------------------------
# Modelfile fetching helper
# ---------------------------------------------------------------------------
# REPO_DIR is set to the directory of the script when run from a clone.
# When piped via curl, REPO_DIR is empty and files are fetched from GitHub.
RAW_BASE="https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main"
TMP_DIR=$(mktemp -d)
# Clean up temp dir on exit (sh-compatible trap)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# get_modelfile FILENAME DEST_PATH
# Copies modelfile from clone dir or fetches from GitHub
get_modelfile() {
  _gm_name="$1"
  _gm_dest="$2"
  if [ -n "${REPO_DIR:-}" ] && [ -f "$REPO_DIR/modelfiles/$_gm_name" ]; then
    cp "$REPO_DIR/modelfiles/$_gm_name" "$_gm_dest"
  else
    curl -fsSL "${RAW_BASE}/modelfiles/${_gm_name}" -o "$_gm_dest"
  fi
}

# ---------------------------------------------------------------------------
# Detect REPO_DIR
# ---------------------------------------------------------------------------
# When run via curl, $0 is 'sh' or similar — REPO_DIR stays empty
# When run as 'sh install.sh' from clone, $0 is the script path
REPO_DIR=""
case "$0" in
  */install.sh)
    REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
    ;;
esac

# ---------------------------------------------------------------------------
# Step 1 — Platform check
# ---------------------------------------------------------------------------
info "Checking platform..."
[ "$(uname -s)" = "Darwin" ] || die "macOS required."
[ "$(uname -m)" = "arm64" ]  || die "Apple Silicon (arm64) required."
ok "macOS Apple Silicon confirmed."

# ---------------------------------------------------------------------------
# Step 2 — Homebrew
# ---------------------------------------------------------------------------
info "Checking Homebrew..."
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed."
  manifest_set installed_brew false
else
  warn "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  manifest_set installed_brew true
  ok "Homebrew installed."
fi

# ---------------------------------------------------------------------------
# Step 3 — Ollama
# ---------------------------------------------------------------------------
info "Checking Ollama..."
if command -v ollama >/dev/null 2>&1; then
  ok "Ollama already installed."
  manifest_set installed_ollama false
else
  warn "Installing Ollama via brew..."
  brew install ollama
  manifest_set installed_ollama true
  ok "Ollama installed."
fi

# ---------------------------------------------------------------------------
# Step 4 — Ensure Ollama is running
# ---------------------------------------------------------------------------
info "Checking if Ollama is running..."
if curl -sf http://localhost:11434/ >/dev/null 2>&1; then
  ok "Ollama is already running."
  manifest_set started_ollama false
else
  warn "Starting Ollama..."
  ollama serve >/dev/null 2>&1 &
  _oll_timeout=15
  while ! curl -sf http://localhost:11434/ >/dev/null 2>&1; do
    sleep 1
    _oll_timeout=$((_oll_timeout - 1))
    [ "$_oll_timeout" -gt 0 ] || die "Ollama failed to start within 15s."
  done
  manifest_set started_ollama true
  ok "Ollama started."
fi

# ---------------------------------------------------------------------------
# Step 5 — Pull qwen3-coder:30b
# ---------------------------------------------------------------------------
info "Checking for qwen3-coder:30b..."
if ollama list 2>/dev/null | grep -q "qwen3-coder:30b"; then
  ok "qwen3-coder:30b already present."
  manifest_set pulled_qwen3_coder false
else
  warn "Pulling qwen3-coder:30b (~15GB, this will take a while)..."
  ollama pull qwen3-coder:30b
  manifest_set pulled_qwen3_coder true
  ok "qwen3-coder:30b pulled."
fi

# ---------------------------------------------------------------------------
# Step 6 — Create model variants (NO arrays — helper called 4 times)
# ---------------------------------------------------------------------------
# Comma-separated string to track what was created this run
CREATED_VARIANTS=""

# create_variant_if_missing VARIANT_NAME MODELFILE_NAME
create_variant_if_missing() {
  _cv_variant="$1"
  _cv_mf="$2"
  info "Checking model variant: $_cv_variant ..."
  if ollama list 2>/dev/null | grep -q "^${_cv_variant}"; then
    ok "$_cv_variant already exists — skipping."
    return 0
  fi
  _cv_dest="$TMP_DIR/$_cv_mf"
  get_modelfile "$_cv_mf" "$_cv_dest"
  warn "Creating $_cv_variant ..."
  ollama create "$_cv_variant" -f "$_cv_dest"
  ok "$_cv_variant created."
  # Append to comma-separated string (no arrays in sh)
  if [ -z "$CREATED_VARIANTS" ]; then
    CREATED_VARIANTS="$_cv_variant"
  else
    CREATED_VARIANTS="${CREATED_VARIANTS},${_cv_variant}"
  fi
}

create_variant_if_missing "devstral-small-2:128k"   "devstral.Modelfile"
create_variant_if_missing "qwen3.5:27b-128k"        "qwen35.Modelfile"
create_variant_if_missing "qwen3-coder:30b-128k"    "qwen3-coder.Modelfile"
create_variant_if_missing "llama3.2:3b-32k"         "llama32.Modelfile"

manifest_set created_variants "$CREATED_VARIANTS"

# ---------------------------------------------------------------------------
# Step 7 — nvm
# ---------------------------------------------------------------------------
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
info "Checking nvm..."
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  ok "nvm already installed."
  manifest_set installed_nvm false
else
  warn "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
  . "$NVM_DIR/nvm.sh"
  manifest_set installed_nvm true
  ok "nvm installed."
fi

# ---------------------------------------------------------------------------
# Step 8 — Node
# ---------------------------------------------------------------------------
info "Checking Node..."
if command -v node >/dev/null 2>&1; then
  ok "Node already available: $(node --version)"
  manifest_set installed_node false
else
  warn "Installing Node LTS via nvm..."
  nvm install --lts
  nvm use --lts
  manifest_set installed_node true
  ok "Node LTS installed."
fi

# ---------------------------------------------------------------------------
# Step 9 — opencode-ai
# ---------------------------------------------------------------------------
info "Checking opencode..."
if command -v opencode >/dev/null 2>&1; then
  ok "opencode already installed."
  manifest_set installed_opencode false
else
  warn "Installing opencode-ai via npm..."
  npm install -g opencode-ai
  manifest_set installed_opencode true
  ok "opencode-ai installed."
fi

# ---------------------------------------------------------------------------
# Step 10 — PATH entry in ~/.zshrc
# ---------------------------------------------------------------------------
OPENCODE_PATH_LINE='export PATH="$HOME/.opencode/bin:$PATH"'
OPENCODE_PATH_COMMENT='# opencode — added by local-agentic-dev'
ZSHRC="$HOME/.zshrc"

info "Checking PATH entry..."
if grep -qF "$OPENCODE_PATH_LINE" "$ZSHRC" 2>/dev/null; then
  ok "PATH entry already in ~/.zshrc"
  manifest_set added_path_entry false
else
  printf '\n%s\n%s\n' "$OPENCODE_PATH_COMMENT" "$OPENCODE_PATH_LINE" >> "$ZSHRC"
  manifest_set added_path_entry true
  ok "PATH entry added to ~/.zshrc"
fi

# ---------------------------------------------------------------------------
# Step 11 — Write opencode.json
# ---------------------------------------------------------------------------
OPENCODE_CFG="$HOME/.config/opencode/opencode.json"
info "Writing opencode config..."

if [ -f "$OPENCODE_CFG" ]; then
  cp "$OPENCODE_CFG" "$HOME/.config/opencode/opencode.json.pre-install-backup"
  warn "Existing config backed up to opencode.json.pre-install-backup"
  manifest_set backed_up_existing_config true
else
  manifest_set backed_up_existing_config false
fi

if [ -n "${REPO_DIR:-}" ] && [ -f "$REPO_DIR/config/opencode.json" ]; then
  cp "$REPO_DIR/config/opencode.json" "$OPENCODE_CFG"
else
  curl -fsSL "${RAW_BASE}/config/opencode.json" -o "$OPENCODE_CFG"
fi

manifest_set wrote_config true
ok "opencode.json written."

# ---------------------------------------------------------------------------
# Step 12 — Verify (non-fatal)
# ---------------------------------------------------------------------------
info "Verifying..."
VERIFY_FAILED=0

OPENCODE_BIN="$(command -v opencode 2>/dev/null || printf '%s' "$HOME/.opencode/bin/opencode")"
if "$OPENCODE_BIN" --version >/dev/null 2>&1; then
  ok "opencode: $("$OPENCODE_BIN" --version 2>/dev/null)"
else
  warn "opencode binary not found in PATH (run 'source ~/.zshrc' after install)"
  VERIFY_FAILED=1
fi

if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
  ok "Ollama API responding."
else
  warn "Ollama API not responding."
  VERIFY_FAILED=1
fi

if ollama list 2>/dev/null | grep -q "qwen3-coder:30b-128k"; then
  ok "Primary model qwen3-coder:30b-128k confirmed."
else
  warn "qwen3-coder:30b-128k not found in ollama list."
  VERIFY_FAILED=1
fi

# ---------------------------------------------------------------------------
# Step 13 — Summary
# ---------------------------------------------------------------------------
printf '\n================================================\n'
printf '  local-agentic-dev: Install Complete\n'
printf '================================================\n\n'
printf '  Default model : qwen3-coder:30b-128k\n'
printf '  All models    : qwen3-coder:30b-128k\n'
printf '                  devstral-small-2:128k\n'
printf '                  qwen3.5:27b-128k\n'
printf '                  llama3.2:3b-32k\n'
printf '  Config        : ~/.config/opencode/opencode.json\n\n'
printf '  Usage: cd /your/project && opencode\n'
printf '  (Run: source ~/.zshrc  if opencode not found)\n\n'

if [ "$VERIFY_FAILED" -eq 1 ]; then
  warn "Some checks failed — see warnings above."
fi
