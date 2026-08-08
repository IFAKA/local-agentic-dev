#!/bin/sh
# uninstall.sh - remove local-agentic-dev generated harness files
set -eu

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

MANIFEST_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
MANIFEST="$MANIFEST_DIR/install-manifest"
LOCAL_AGENT_REMOVE_PI="${LOCAL_AGENT_REMOVE_PI:-false}"

manifest_get() {
  if [ -f "$MANIFEST" ]; then
    grep "^${1}=" "$MANIFEST" 2>/dev/null | cut -d= -f2- || true
  fi
}

restore_backup() {
  _file="$1"
  _backup="$_file.pre-local-agentic-dev"
  if [ -f "$_backup" ]; then
    if [ -f "$_file" ]; then
      cp "$_file" "$_file.removed-local-agentic-dev"
      rm -f "$_file"
    fi
    mv "$_backup" "$_file"
    ok "Restored $_file"
  elif [ -f "$_file" ]; then
    cp "$_file" "$_file.removed-local-agentic-dev"
    rm -f "$_file"
    ok "Removed generated $_file"
  fi
}

[ -f "$MANIFEST" ] || die "No install manifest at $MANIFEST."

HARNESS="$(manifest_get harness)"
PI_LAUNCH_AGENT="$(manifest_get pi_launch_agent)"
PI_AGENT_DIR="$(manifest_get pi_agent_dir)"
PI_MODEL_FILE="$(manifest_get pi_model_file)"
PI_RAPID_LAUNCH_AGENT="$(manifest_get pi_rapid_launch_agent)"
PI_RAPID_LAUNCH_LABEL="${PI_RAPID_LAUNCH_LABEL:-com.local-agentic-dev.rapid-mlx}"
PI_PACKAGE="$(manifest_get pi_package)"
AIDER_CONFIG="$(manifest_get aider_config)"
AIDER_ENV="$(manifest_get aider_env)"
AIDER_WRAPPER="$(manifest_get aider_wrapper)"
HOME_AIDER_CONFIG="$(manifest_get home_aider_config)"
PI_LAUNCH_LABEL="${PI_LAUNCH_LABEL:-com.faka.pi-qwen36}"

if [ -n "$PI_RAPID_LAUNCH_AGENT" ]; then
  info "Stopping Rapid-MLX LaunchAgent..."
  launchctl bootout "gui/$(id -u)" "$PI_RAPID_LAUNCH_AGENT" >/dev/null 2>&1 || true
  rm -f "$PI_RAPID_LAUNCH_AGENT"
  ok "Removed $PI_RAPID_LAUNCH_AGENT"
else
  launchctl bootout "gui/$(id -u)/$PI_RAPID_LAUNCH_LABEL" >/dev/null 2>&1 || true
fi

info "Leaving any independently installed Ollama, OpenCode, Aider, and model caches untouched."

if [ -n "$PI_AGENT_DIR" ]; then
  info "Restoring Pi config backups if present..."
  restore_backup "$PI_AGENT_DIR/settings.json"
  restore_backup "$PI_AGENT_DIR/models.json"
fi

if [ "$(manifest_get installed_pi)" = "true" ]; then
  if [ "$LOCAL_AGENT_REMOVE_PI" = "true" ]; then
    info "Removing Pi CLI because it was installed by this harness and LOCAL_AGENT_REMOVE_PI=true..."
    if [ -n "$PI_PACKAGE" ]; then
      npm uninstall -g "$PI_PACKAGE" || warn "Could not remove Pi CLI package $PI_PACKAGE."
    else
      npm uninstall -g @earendil-works/pi-coding-agent || warn "Could not remove Pi CLI."
    fi
  else
    info "Keeping Pi CLI. Set LOCAL_AGENT_REMOVE_PI=true ./uninstall.sh to remove it when it was installed by this harness."
  fi
else
  info "Keeping Pi CLI because it was not installed by this harness."
fi

if [ -n "$PI_MODEL_FILE" ]; then
  info "Keeping shared legacy model file by default: $PI_MODEL_FILE"
fi

rm -f "$MANIFEST"
rmdir "$MANIFEST_DIR" 2>/dev/null || true

printf '\n================================================\n'
printf '  Local Agentic Dev Harness Removed\n'
printf '================================================\n\n'
