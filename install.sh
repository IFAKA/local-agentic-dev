#!/bin/sh
# install.sh - Aider + Qwen 3.6 local coding agent
# curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
set -eu

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ ok ]  %s\n' "$*"; }
warn() { printf '[warn]  %s\n' "$*"; }
die()  { printf '[fail]  %s\n' "$*" >&2; exit 1; }

LOCAL_AGENT_HARNESS="${LOCAL_AGENT_HARNESS:-aider}"
LOCAL_AGENT_BIN_DIR="${LOCAL_AGENT_BIN_DIR:-$HOME/.local/bin}"
LOCAL_AGENT_CONFIG_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
LOCAL_AGENT_WRAPPER="${LOCAL_AGENT_WRAPPER:-local-code}"
LOCAL_AGENT_REMOVE_PI="${LOCAL_AGENT_REMOVE_PI:-true}"
LOCAL_AGENT_WRITE_HOME_AIDER_CONFIG="${LOCAL_AGENT_WRITE_HOME_AIDER_CONFIG:-true}"
LOCAL_AGENT_REASONING="${LOCAL_AGENT_REASONING:-off}"
PI_MODEL_ID="${PI_MODEL_ID:-qwen3.6-27b-reasoning}"
PI_MODEL_FILE="${PI_MODEL_FILE:-Qwen3.6-27B-Claude-Opus-Reasoning-Distill.q6_k.gguf}"
PI_CONTEXT="${PI_CONTEXT:-32768}"
PI_MAX_TOKENS="${PI_MAX_TOKENS:-8192}"
PI_PARALLEL="${PI_PARALLEL:-1}"
PI_DEFAULT_THINKING="${PI_DEFAULT_THINKING:-high}"
PI_REPLACE_PORT_OWNER="${PI_REPLACE_PORT_OWNER:-true}"
PI_DISABLE_LEGACY_AGENTS="${PI_DISABLE_LEGACY_AGENTS:-true}"
PI_LEGACY_LABELS="${PI_LEGACY_LABELS:-ollama.custom}"
PI_HOST="${PI_HOST:-127.0.0.1}"
PI_PORT="${PI_PORT:-11435}"
PI_SHARED_DIR="${PI_SHARED_DIR:-/Users/Shared/pi-qwen36}"
PI_LOCAL_MODEL_DIR="${PI_LOCAL_MODEL_DIR:-$HOME/.ollama-pi-qwen36}"
PI_GGUF_URL="${PI_GGUF_URL:-}"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
AIDER_CONFIG_FILE="$LOCAL_AGENT_CONFIG_DIR/aider.conf.yml"
AIDER_ENV_FILE="$LOCAL_AGENT_CONFIG_DIR/aider.env"
AIDER_WRAPPER_PATH="$LOCAL_AGENT_BIN_DIR/$LOCAL_AGENT_WRAPPER"
PI_LAUNCH_LABEL="${PI_LAUNCH_LABEL:-com.faka.pi-qwen36}"
PI_LAUNCH_AGENT="$HOME/Library/LaunchAgents/$PI_LAUNCH_LABEL.plist"
PI_SHARED_MODEL="$PI_SHARED_DIR/$PI_MODEL_FILE"
PI_LOCAL_MODEL="$PI_LOCAL_MODEL_DIR/$PI_MODEL_FILE"
MANIFEST_DIR="$LOCAL_AGENT_CONFIG_DIR"
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

if ! command -v aider >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    uv tool install aider-chat
  elif command -v pipx >/dev/null 2>&1; then
    pipx install aider-chat
  else
    python3 -m pip install --user aider-chat
  fi
fi
command -v aider >/dev/null 2>&1 || die "aider was installed but is not on PATH. Add ~/.local/bin to PATH and rerun."

PI_MODEL_ID_JSON=$(json_escape "$PI_MODEL_ID")
PI_BASE_URL="http://$PI_HOST:$PI_PORT/v1"
PI_BASE_URL_JSON=$(json_escape "$PI_BASE_URL")

info "Writing Aider config..."
mkdir -p "$LOCAL_AGENT_CONFIG_DIR" "$LOCAL_AGENT_BIN_DIR"
if [ -f "$HOME/.aider.conf.yml" ] && [ ! -f "$HOME/.aider.conf.yml.pre-local-agentic-dev" ]; then
  cp "$HOME/.aider.conf.yml" "$HOME/.aider.conf.yml.pre-local-agentic-dev"
fi

cat > "$AIDER_ENV_FILE" <<EOF
OPENAI_API_KEY=local
OPENAI_API_BASE=$PI_BASE_URL
EOF

cat > "$AIDER_CONFIG_FILE" <<EOF
model: openai/$PI_MODEL_ID_JSON
openai-api-base: $PI_BASE_URL_JSON
openai-api-key: local
edit-format: diff
show-model-warnings: false
check-model-accepts-settings: false
analytics-disable: true
auto-commits: false
dirty-commits: false
attribute-co-authored-by: false
max-chat-history-tokens: 20000
map-tokens: 4096
map-refresh: auto
cache-prompts: false
suggest-shell-commands: true
EOF

if [ "$LOCAL_AGENT_WRITE_HOME_AIDER_CONFIG" = "true" ]; then
  cp "$AIDER_CONFIG_FILE" "$HOME/.aider.conf.yml"
  manifest_set wrote_home_aider_config true
else
  manifest_set wrote_home_aider_config false
fi

cat > "$AIDER_WRAPPER_PATH" <<EOF
#!/bin/sh
set -eu
CONFIG_FILE="${LOCAL_AGENT_CONFIG_DIR}/aider.conf.yml"
if [ ! -f "\$CONFIG_FILE" ]; then
  printf 'Missing %s. Re-run local-agentic-dev install.sh.\n' "\$CONFIG_FILE" >&2
  exit 1
fi
exec aider --config "\$CONFIG_FILE" "\$@"
EOF
chmod 755 "$AIDER_WRAPPER_PATH"
ok "Installed Aider config: $AIDER_CONFIG_FILE"
ok "Installed wrapper command: $AIDER_WRAPPER_PATH"

if [ "$LOCAL_AGENT_REMOVE_PI" = "true" ] && command -v pi >/dev/null 2>&1; then
  info "Removing Pi CLI because LOCAL_AGENT_REMOVE_PI=true..."
  npm uninstall -g @mariozechner/pi-coding-agent >/dev/null 2>&1 || warn "Could not remove global Pi CLI."
fi
manifest_set installed_pi false

info "Writing launch agent: $PI_LAUNCH_AGENT"
mkdir -p "$HOME/Library/LaunchAgents" "$LOCAL_AGENT_CONFIG_DIR/logs"
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
    <string>-np</string>
    <string>$PI_PARALLEL</string>
    <string>--host</string>
    <string>$PI_HOST</string>
    <string>--port</string>
    <string>$PI_PORT</string>
    <string>-a</string>
    <string>$PI_MODEL_ID</string>
    <string>--reasoning</string>
    <string>$LOCAL_AGENT_REASONING</string>
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
  <string>$LOCAL_AGENT_CONFIG_DIR/logs/llama-server.log</string>
  <key>StandardErrorPath</key>
  <string>$LOCAL_AGENT_CONFIG_DIR/logs/llama-server.err.log</string>
</dict>
</plist>
EOF

manifest_set pi_model_id "$PI_MODEL_ID"
manifest_set pi_model_file "$PI_SHARED_MODEL"
manifest_set pi_port "$PI_PORT"
manifest_set pi_context "$PI_CONTEXT"
manifest_set pi_max_tokens "$PI_MAX_TOKENS"
manifest_set pi_parallel "$PI_PARALLEL"
manifest_set local_agent_reasoning "$LOCAL_AGENT_REASONING"
manifest_set pi_launch_agent "$PI_LAUNCH_AGENT"
manifest_set pi_agent_dir "$PI_AGENT_DIR"
manifest_set harness "$LOCAL_AGENT_HARNESS"
manifest_set aider_config "$AIDER_CONFIG_FILE"
manifest_set aider_env "$AIDER_ENV_FILE"
manifest_set aider_wrapper "$AIDER_WRAPPER_PATH"
manifest_set home_aider_config "$HOME/.aider.conf.yml"

if [ "$PI_DISABLE_LEGACY_AGENTS" = "true" ]; then
  for _legacy_label in $PI_LEGACY_LABELS; do
    _legacy_plist="$HOME/Library/LaunchAgents/${_legacy_label}.plist"
    if [ -f "$_legacy_plist" ]; then
      warn "Disabling legacy LaunchAgent $_legacy_label to prevent port conflicts."
      launchctl bootout "gui/$(id -u)/$_legacy_label" >/dev/null 2>&1 || true
      mv "$_legacy_plist" "$_legacy_plist.disabled-local-agentic-dev" 2>/dev/null || true
      manifest_set "legacy_${_legacy_label}_plist" "$_legacy_plist.disabled-local-agentic-dev"
    else
      launchctl bootout "gui/$(id -u)/$_legacy_label" >/dev/null 2>&1 || true
    fi
  done
fi

if [ "$PI_REPLACE_PORT_OWNER" = "true" ] && command -v lsof >/dev/null 2>&1; then
  _pids=$(lsof -tiTCP:"$PI_PORT" -sTCP:LISTEN 2>/dev/null || true)
  if [ -n "$_pids" ]; then
    warn "Stopping existing process(es) listening on port $PI_PORT: $_pids"
    kill $_pids 2>/dev/null || true
    sleep 2
  fi
fi

info "Starting local model server..."
launchctl bootout "gui/$(id -u)" "$PI_LAUNCH_AGENT" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PI_LAUNCH_AGENT" >/dev/null 2>&1 || true
launchctl enable "gui/$(id -u)/$PI_LAUNCH_LABEL" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$(id -u)/$PI_LAUNCH_LABEL" >/dev/null 2>&1 || true

_timeout=30
while ! curl -sf "http://$PI_HOST:$PI_PORT/v1/models" >/dev/null 2>&1; do
  sleep 1
  _timeout=$((_timeout - 1))
  [ "$_timeout" -gt 0 ] || die "Local model server did not answer on $PI_HOST:$PI_PORT. Check $LOCAL_AGENT_CONFIG_DIR/logs/llama-server.err.log"
done

ok "Local model server is ready."
printf '\n================================================\n'
printf '  Aider + Qwen 3.6 Setup Complete\n'
printf '================================================\n\n'
printf '  Commands: aider  or  %s\n' "$LOCAL_AGENT_WRAPPER"
printf '  Model   : openai/%s\n' "$PI_MODEL_ID"
printf '  Server  : http://%s:%s/v1\n' "$PI_HOST" "$PI_PORT"
printf '  Context : %s\n' "$PI_CONTEXT"
printf '  Parallel: %s\n' "$PI_PARALLEL"
printf '  Reason  : %s\n' "$LOCAL_AGENT_REASONING"
printf '  Config  : %s\n' "$AIDER_CONFIG_FILE"
printf '  GGUF    : %s\n\n' "$PI_SHARED_MODEL"
