#!/bin/sh
# uninstall.sh — local-agentic-dev
# curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/uninstall.sh | sh
set -eu

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Manifest helper
# ---------------------------------------------------------------------------
# manifest_get KEY — prints the value, or empty string
manifest_get() {
  if [ -f "$MANIFEST" ]; then
    grep "^${1}=" "$MANIFEST" 2>/dev/null | cut -d= -f2- || true
  fi
}

# ---------------------------------------------------------------------------
# Step 1 — Check manifest exists
# ---------------------------------------------------------------------------
MANIFEST="$HOME/.config/opencode/.install-manifest"
[ -f "$MANIFEST" ] || die "No install manifest at $MANIFEST — nothing to uninstall."
info "Found manifest. Starting uninstall..."

# ---------------------------------------------------------------------------
# Step 2 — Ensure Ollama running (needed for ollama rm)
# ---------------------------------------------------------------------------
info "Ensuring Ollama is running..."
if ! curl -sf http://localhost:11434/ >/dev/null 2>&1; then
  warn "Starting Ollama to remove model variants..."
  ollama serve >/dev/null 2>&1 &
  _oll_timeout=15
  while ! curl -sf http://localhost:11434/ >/dev/null 2>&1; do
    sleep 1
    _oll_timeout=$((_oll_timeout - 1))
    [ "$_oll_timeout" -gt 0 ] || die "Ollama failed to start within 15s."
  done
fi
ok "Ollama is running."

# ---------------------------------------------------------------------------
# Step 3 — Remove model variants
# ---------------------------------------------------------------------------
info "Removing model variants..."
CREATED_RAW="$(manifest_get created_variants)"
if [ -n "$CREATED_RAW" ]; then
  # Split comma-separated string — POSIX sh way (no arrays)
  OLD_IFS="$IFS"
  IFS=','
  for _variant in $CREATED_RAW; do
    [ -z "$_variant" ] && continue
    if ollama list 2>/dev/null | grep -q "^${_variant}"; then
      warn "Removing $_variant ..."
      ollama rm "$_variant"
      ok "Removed $_variant"
    else
      info "$_variant not found — skipping."
    fi
  done
  IFS="$OLD_IFS"
else
  info "No model variants in manifest — skipping."
fi

# ---------------------------------------------------------------------------
# Step 4 — Backup + remove opencode.json
# ---------------------------------------------------------------------------
OPENCODE_CFG="$HOME/.config/opencode/opencode.json"
BACKUP="$HOME/opencode-config.backup.json"
PRE_INSTALL_BACKUP="$HOME/.config/opencode/opencode.json.pre-install-backup"

info "Backing up config..."
if [ -f "$OPENCODE_CFG" ]; then
  cp "$OPENCODE_CFG" "$BACKUP"
  ok "Config backed up to ~/opencode-config.backup.json"
  rm -f "$OPENCODE_CFG"
fi

# Restore the config that existed before install, if any
if [ -f "$PRE_INSTALL_BACKUP" ]; then
  mv "$PRE_INSTALL_BACKUP" "$OPENCODE_CFG"
  ok "Pre-install config restored."
fi

# ---------------------------------------------------------------------------
# Step 5 — Remove manifest
# ---------------------------------------------------------------------------
rm -f "$MANIFEST"
ok "Manifest removed."

# ---------------------------------------------------------------------------
# Step 6 — Remove opencode npm package (only if we installed it)
# ---------------------------------------------------------------------------
if [ "$(manifest_get installed_opencode)" = "true" ]; then
  info "Removing opencode-ai from npm..."
  NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  npm uninstall -g opencode-ai && ok "opencode-ai removed." || warn "Could not remove opencode-ai from npm."
else
  info "opencode was pre-existing — leaving it."
fi

# ---------------------------------------------------------------------------
# Step 7 — Remove PATH entry (only if we added it)
# ---------------------------------------------------------------------------
if [ "$(manifest_get added_path_entry)" = "true" ]; then
  ZSHRC="$HOME/.zshrc"
  if [ -f "$ZSHRC" ]; then
    info "Removing PATH entry from ~/.zshrc..."
    _tmp=$(mktemp)
    grep -vF '# opencode — added by local-agentic-dev' "$ZSHRC" | \
      grep -vF 'export PATH="$HOME/.opencode/bin:$PATH"' > "$_tmp"
    mv "$_tmp" "$ZSHRC"
    ok "PATH entry removed."
  fi
else
  info "PATH entry was pre-existing — leaving it."
fi

# ---------------------------------------------------------------------------
# Step 8 — Self-delete (only if running from a cloned directory)
# ---------------------------------------------------------------------------
SCRIPT_DIR=""
case "$0" in
  */uninstall.sh)
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ;;
esac

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ] && [ "$SCRIPT_DIR" != "$HOME" ]; then
  warn "Removing repo directory: $SCRIPT_DIR"
  rm -rf "$SCRIPT_DIR"
  ok "Repo directory removed."
else
  info "Running via curl — skipping self-delete."
fi

# ---------------------------------------------------------------------------
# Step 9 — Summary
# ---------------------------------------------------------------------------
printf '\n================================================\n'
printf '  local-agentic-dev: Uninstall Complete\n'
printf '================================================\n\n'
printf '  Kept: base Ollama models (no re-download needed)\n'
printf '  Config backup: ~/opencode-config.backup.json\n'
printf '  Run: source ~/.zshrc\n\n'
