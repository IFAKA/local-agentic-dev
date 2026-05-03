#!/bin/sh
# uninstall.sh - Aider + Qwen 3.6 local coding agent
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
AIDER_CONFIG="$(manifest_get aider_config)"
AIDER_ENV="$(manifest_get aider_env)"
AIDER_WRAPPER="$(manifest_get aider_wrapper)"
HOME_AIDER_CONFIG="$(manifest_get home_aider_config)"
PI_LAUNCH_LABEL="${PI_LAUNCH_LABEL:-com.faka.pi-qwen36}"

info "Stopping launch agent..."
if [ -n "$PI_LAUNCH_AGENT" ] && [ -f "$PI_LAUNCH_AGENT" ]; then
  launchctl bootout "gui/$(id -u)" "$PI_LAUNCH_AGENT" >/dev/null 2>&1 || true
  rm -f "$PI_LAUNCH_AGENT"
  ok "Removed $PI_LAUNCH_AGENT"
else
  launchctl bootout "gui/$(id -u)/$PI_LAUNCH_LABEL" >/dev/null 2>&1 || true
fi

if [ -n "$AIDER_WRAPPER" ] && [ -f "$AIDER_WRAPPER" ]; then
  info "Removing Aider wrapper..."
  rm -f "$AIDER_WRAPPER"
fi

if [ -n "$AIDER_CONFIG" ] && [ -f "$AIDER_CONFIG" ]; then
  info "Removing Aider config..."
  rm -f "$AIDER_CONFIG"
fi
if [ -n "$AIDER_ENV" ] && [ -f "$AIDER_ENV" ]; then
  rm -f "$AIDER_ENV"
fi
if [ "$(manifest_get wrote_home_aider_config)" = "true" ] && [ -n "$HOME_AIDER_CONFIG" ]; then
  if [ -f "$HOME_AIDER_CONFIG" ]; then
    cp "$HOME_AIDER_CONFIG" "$HOME/aider-conf.backup.yml"
    rm -f "$HOME_AIDER_CONFIG"
  fi
  if [ -f "$HOME/.aider.conf.yml.pre-local-agentic-dev" ]; then
    mv "$HOME/.aider.conf.yml.pre-local-agentic-dev" "$HOME/.aider.conf.yml"
  fi
fi

if [ -n "$PI_AGENT_DIR" ]; then
  info "Restoring old Pi config backups if present..."
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
printf '  Aider Local Setup Removed\n'
printf '================================================\n\n'
