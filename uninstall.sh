#!/bin/sh
# uninstall.sh — Pi + Qwen 3.6 local coding agent
set -eu

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

MANIFEST_DIR="$HOME/.config/local-agentic-dev"
MANIFEST="$MANIFEST_DIR/install-manifest"

manifest_get() {
  if [ -f "$MANIFEST" ]; then
    grep "^${1}=" "$MANIFEST" 2>/dev/null | cut -d= -f2- || true
  fi
}

[ -f "$MANIFEST" ] || die "No install manifest at $MANIFEST."

PI_LAUNCH_AGENT="$(manifest_get pi_launch_agent)"
PI_AGENT_DIR="$(manifest_get pi_agent_dir)"
PI_MODEL_FILE="$(manifest_get pi_model_file)"
PI_LAUNCH_LABEL="${PI_LAUNCH_LABEL:-com.faka.pi-qwen36}"

info "Stopping launch agent..."
if [ -n "$PI_LAUNCH_AGENT" ] && [ -f "$PI_LAUNCH_AGENT" ]; then
  launchctl bootout "gui/$(id -u)" "$PI_LAUNCH_AGENT" >/dev/null 2>&1 || true
  rm -f "$PI_LAUNCH_AGENT"
  ok "Removed $PI_LAUNCH_AGENT"
else
  launchctl bootout "gui/$(id -u)/$PI_LAUNCH_LABEL" >/dev/null 2>&1 || true
fi

if [ -n "$PI_AGENT_DIR" ]; then
  info "Restoring Pi config backups..."
  if [ -f "$PI_AGENT_DIR/settings.json" ]; then
    cp "$PI_AGENT_DIR/settings.json" "$HOME/pi-settings.backup.json"
    rm -f "$PI_AGENT_DIR/settings.json"
  fi
  if [ -f "$PI_AGENT_DIR/settings.json.pre-local-agentic-dev" ]; then
    mv "$PI_AGENT_DIR/settings.json.pre-local-agentic-dev" "$PI_AGENT_DIR/settings.json"
  fi
  if [ -f "$PI_AGENT_DIR/models.json" ]; then
    cp "$PI_AGENT_DIR/models.json" "$HOME/pi-models.backup.json"
    rm -f "$PI_AGENT_DIR/models.json"
  fi
  if [ -f "$PI_AGENT_DIR/models.json.pre-local-agentic-dev" ]; then
    mv "$PI_AGENT_DIR/models.json.pre-local-agentic-dev" "$PI_AGENT_DIR/models.json"
  fi
fi

if [ "$(manifest_get installed_pi)" = "true" ]; then
  info "Removing pi CLI..."
  npm uninstall -g @mariozechner/pi-coding-agent || warn "Could not remove pi CLI."
fi

info "Keeping shared model file by default: $PI_MODEL_FILE"
info "Delete it manually only when no macOS user needs it."

rm -f "$MANIFEST"
rmdir "$MANIFEST_DIR" 2>/dev/null || true

printf '\n================================================\n'
printf '  Pi Local Setup Removed\n'
printf '================================================\n\n'
