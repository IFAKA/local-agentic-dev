#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LOCAL_AGENT_REPO_ROOT="$ROOT"; export LOCAL_AGENT_REPO_ROOT
. "$ROOT/lib/config.sh"
if [ -x "$ROOT/bin/local-agent" ]; then "$ROOT/bin/local-agent" stop >/dev/null 2>&1 || true; fi
for label in com.local-agentic-dev.rapid-mlx com.local-agentic-dev.nemotron-rapid-mlx; do
  plist="$HOME/Library/LaunchAgents/$label.plist"
  if [ -f "$plist" ]; then launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true; rm -f "$plist"; printf 'Removed %s\n' "$plist"; fi
done
if [ -f "$CONFIG_DIR/backups/pi-models.json" ]; then [ -f "$PI_AGENT_DIR/models.json" ] && mv "$PI_AGENT_DIR/models.json" "$PI_AGENT_DIR/models.json.removed-local-agentic-dev"; cp -p "$CONFIG_DIR/backups/pi-models.json" "$PI_AGENT_DIR/models.json"; printf 'Restored Pi models.json\n'; fi
if [ -f "$CONFIG_DIR/backups/pi-settings.json" ]; then [ -f "$PI_AGENT_DIR/settings.json" ] && mv "$PI_AGENT_DIR/settings.json" "$PI_AGENT_DIR/settings.json.removed-local-agentic-dev"; cp -p "$CONFIG_DIR/backups/pi-settings.json" "$PI_AGENT_DIR/settings.json"; printf 'Restored Pi settings.json\n'; fi
legacy_little="$HOME/.config/little-coder/models.json"
if [ -f "$legacy_little.pre-local-agentic-dev" ] && [ ! -f "$legacy_little" ]; then cp -p "$legacy_little.pre-local-agentic-dev" "$legacy_little"; printf 'Restored Little Coder config backup\n'; fi
rm -f "$HOME/.local/bin/local-agent"
rm -rf "$CONFIG_DIR"
printf '%s\n' 'Removed project configuration, logs, PID state, backups, and services.'
printf '%s\n' 'Preserved downloaded models and Rapid-MLX/Pi packages.'
