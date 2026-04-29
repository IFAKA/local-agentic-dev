#!/bin/sh
# install.sh — Pi + Qwen 3.6 local coding agent
# curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
set -eu

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

PI_MODEL_ID="${PI_MODEL_ID:-qwen3.6-27b-reasoning}"
PI_MODEL_FILE="${PI_MODEL_FILE:-Qwen3.6-27B-Claude-Opus-Reasoning-Distill.q6_k.gguf}"
PI_CONTEXT="${PI_CONTEXT:-32768}"
PI_HOST="${PI_HOST:-127.0.0.1}"
PI_PORT="${PI_PORT:-11435}"
PI_SHARED_DIR="${PI_SHARED_DIR:-/Users/Shared/pi-qwen36}"
PI_LOCAL_MODEL_DIR="${PI_LOCAL_MODEL_DIR:-$HOME/.ollama-pi-qwen36}"
PI_GGUF_URL="${PI_GGUF_URL:-}"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PI_LAUNCH_LABEL="${PI_LAUNCH_LABEL:-com.faka.pi-qwen36}"
PI_LAUNCH_AGENT="$HOME/Library/LaunchAgents/$PI_LAUNCH_LABEL.plist"
PI_SHARED_MODEL="$PI_SHARED_DIR/$PI_MODEL_FILE"
PI_LOCAL_MODEL="$PI_LOCAL_MODEL_DIR/$PI_MODEL_FILE"
MANIFEST_DIR="$HOME/.config/local-agentic-dev"
MANIFEST="$MANIFEST_DIR/install-manifest"

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

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

info "Checking platform..."
[ "$(uname -s)" = "Darwin" ] || die "macOS required."
[ "$(uname -m)" = "arm64" ] || die "Apple Silicon required."

TOTAL_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || printf '0')
TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))
info "Detected ${TOTAL_RAM_GB}GB unified memory."
if [ "$TOTAL_RAM_GB" -lt 32 ]; then
  warn "Qwen 3.6 27B Q6 is intended for 32GB+ Macs and is best on 48GB+."
fi

info "Preparing shared model directory: $PI_SHARED_DIR"
mkdir -p "$PI_SHARED_DIR"
chmod 775 "$PI_SHARED_DIR" 2>/dev/null || true

if [ -f "$PI_SHARED_MODEL" ]; then
  ok "Shared GGUF already exists: $PI_SHARED_MODEL"
elif [ -f "$PI_LOCAL_MODEL" ]; then
  info "Copying existing Pi GGUF into shared storage..."
  cp "$PI_LOCAL_MODEL" "$PI_SHARED_MODEL"
  chmod 664 "$PI_SHARED_MODEL" 2>/dev/null || true
  ok "Copied model to $PI_SHARED_MODEL"
elif [ -n "$PI_GGUF_URL" ]; then
  warn "Shared GGUF not found. Downloading once from PI_GGUF_URL..."
  curl -fL "$PI_GGUF_URL" -o "$PI_SHARED_MODEL"
  chmod 664 "$PI_SHARED_MODEL" 2>/dev/null || true
else
  die "Missing $PI_SHARED_MODEL. Run this first from the user that already has $PI_LOCAL_MODEL, or set PI_GGUF_URL."
fi

command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
command -v llama-server >/dev/null 2>&1 || brew install llama.cpp
command -v node >/dev/null 2>&1 || brew install node
if command -v pi >/dev/null 2>&1; then
  manifest_set installed_pi false
else
  npm install -g @mariozechner/pi-coding-agent
  manifest_set installed_pi true
fi

info "Writing Pi config..."
mkdir -p "$PI_AGENT_DIR"
if [ -f "$PI_AGENT_DIR/settings.json" ] && [ ! -f "$PI_AGENT_DIR/settings.json.pre-local-agentic-dev" ]; then
  cp "$PI_AGENT_DIR/settings.json" "$PI_AGENT_DIR/settings.json.pre-local-agentic-dev"
fi
if [ -f "$PI_AGENT_DIR/models.json" ] && [ ! -f "$PI_AGENT_DIR/models.json.pre-local-agentic-dev" ]; then
  cp "$PI_AGENT_DIR/models.json" "$PI_AGENT_DIR/models.json.pre-local-agentic-dev"
fi

PI_MODEL_ID_JSON=$(json_escape "$PI_MODEL_ID")
PI_BASE_URL_JSON=$(json_escape "http://$PI_HOST:$PI_PORT/v1")

cat > "$PI_AGENT_DIR/settings.json" <<EOF
{
  "defaultProvider": "ollama",
  "defaultModel": "$PI_MODEL_ID_JSON",
  "enableInstallTelemetry": false
}
EOF

cat > "$PI_AGENT_DIR/models.json" <<EOF
{
  "providers": {
    "ollama": {
      "baseUrl": "$PI_BASE_URL_JSON",
      "api": "openai-completions",
      "apiKey": "local",
      "models": [
        {
          "id": "$PI_MODEL_ID_JSON",
          "name": "Qwen 3.6 27B Reasoning Q6",
          "compat": {
            "supportsDeveloperRole": true,
            "supportsReasoningEffort": true
          }
        }
      ]
    }
  }
}
EOF

info "Writing launch agent: $PI_LAUNCH_AGENT"
mkdir -p "$HOME/Library/LaunchAgents" "$PI_AGENT_DIR/logs"
cat > "$PI_LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PI_LAUNCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v llama-server)</string>
    <string>-m</string>
    <string>$PI_SHARED_MODEL</string>
    <string>-c</string>
    <string>$PI_CONTEXT</string>
    <string>--host</string>
    <string>$PI_HOST</string>
    <string>--port</string>
    <string>$PI_PORT</string>
    <string>-a</string>
    <string>$PI_MODEL_ID</string>
    <string>--reasoning</string>
    <string>on</string>
    <string>--no-webui</string>
    <string>--temp</string>
    <string>0.35</string>
    <string>--top-p</string>
    <string>0.9</string>
    <string>--top-k</string>
    <string>20</string>
    <string>--min-p</string>
    <string>0</string>
    <string>--repeat-penalty</string>
    <string>1.05</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$PI_AGENT_DIR/logs/llama-server.log</string>
  <key>StandardErrorPath</key>
  <string>$PI_AGENT_DIR/logs/llama-server.err.log</string>
</dict>
</plist>
EOF

manifest_set pi_model_id "$PI_MODEL_ID"
manifest_set pi_model_file "$PI_SHARED_MODEL"
manifest_set pi_port "$PI_PORT"
manifest_set pi_launch_agent "$PI_LAUNCH_AGENT"
manifest_set pi_agent_dir "$PI_AGENT_DIR"

info "Starting Pi model server..."
launchctl bootout "gui/$(id -u)" "$PI_LAUNCH_AGENT" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PI_LAUNCH_AGENT" >/dev/null 2>&1 || true
launchctl enable "gui/$(id -u)/$PI_LAUNCH_LABEL" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$(id -u)/$PI_LAUNCH_LABEL" >/dev/null 2>&1 || true

_timeout=30
while ! curl -sf "http://$PI_HOST:$PI_PORT/v1/models" >/dev/null 2>&1; do
  sleep 1
  _timeout=$((_timeout - 1))
  [ "$_timeout" -gt 0 ] || die "Pi model server did not answer on $PI_HOST:$PI_PORT. Check $PI_AGENT_DIR/logs/llama-server.err.log"
done

ok "Pi model server is ready."
printf '\n================================================\n'
printf '  Pi + Qwen 3.6 Setup Complete\n'
printf '================================================\n\n'
printf '  Command : pi\n'
printf '  Model   : %s\n' "$PI_MODEL_ID"
printf '  Server  : http://%s:%s/v1\n' "$PI_HOST" "$PI_PORT"
printf '  GGUF    : %s\n\n' "$PI_SHARED_MODEL"
