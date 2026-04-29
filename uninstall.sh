#!/bin/sh
# uninstall.sh — local-agentic-dev Pi agent setup
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

PI_AGENT_MODEL="$(manifest_get pi_agent_model)"
OLLAMA_MODELS_DIR="$(manifest_get ollama_models_dir)"

info "Removing generated app configs..."
OPENCODE_CFG="$HOME/.config/opencode/opencode.json"
OPENCODE_BACKUP="$HOME/.config/opencode/opencode.json.pre-local-agentic-dev"
if [ -f "$OPENCODE_CFG" ]; then
  cp "$OPENCODE_CFG" "$HOME/opencode-config.backup.json"
  rm -f "$OPENCODE_CFG"
  ok "Backed up OpenCode config to ~/opencode-config.backup.json"
fi
if [ -f "$OPENCODE_BACKUP" ]; then
  mv "$OPENCODE_BACKUP" "$OPENCODE_CFG"
  ok "Restored previous OpenCode config."
fi

AIDER_CFG="$HOME/.aider.conf.yml"
AIDER_BACKUP="$HOME/.aider.conf.yml.pre-local-agentic-dev"
if [ -f "$AIDER_CFG" ]; then
  cp "$AIDER_CFG" "$HOME/aider-config.backup.yml"
  rm -f "$AIDER_CFG"
  ok "Backed up Aider config to ~/aider-config.backup.yml"
fi
if [ -f "$AIDER_BACKUP" ]; then
  mv "$AIDER_BACKUP" "$AIDER_CFG"
  ok "Restored previous Aider config."
fi

if [ -n "$OLLAMA_MODELS_DIR" ] && [ "$OLLAMA_MODELS_DIR" != "$HOME/.ollama/models" ]; then
  info "Keeping shared Ollama cache at $OLLAMA_MODELS_DIR."
  info "Keeping Pi agent model: $PI_AGENT_MODEL"
  info "Set REMOVE_SHARED_OLLAMA_MODELS=1 before running uninstall if you want to remove shared model data manually afterward."
elif [ "${REMOVE_SHARED_OLLAMA_MODELS:-0}" = "1" ] && [ -n "$PI_AGENT_MODEL" ]; then
  info "Removing model $PI_AGENT_MODEL ..."
  ollama rm "$PI_AGENT_MODEL" || warn "Could not remove $PI_AGENT_MODEL."
fi

if [ "$(manifest_get installed_opencode)" = "true" ]; then
  info "Removing opencode-ai..."
  npm uninstall -g opencode-ai || warn "Could not remove opencode-ai."
fi

rm -f "$MANIFEST"
rmdir "$MANIFEST_DIR" 2>/dev/null || true

printf '\n================================================\n'
printf '  Pi Agent Local Setup Removed\n'
printf '================================================\n\n'
printf '  Shared Ollama models were kept by default.\n\n'
