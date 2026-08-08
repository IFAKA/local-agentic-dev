#!/bin/sh
# install.sh - Pi + Rapid-MLX coding harness
set -eu

START_TIME=$(date +%s)
STEP=0

usage() {
  cat <<'EOF_USAGE'
Usage: ./install.sh [--deep-reasoning]

Environment overrides:
  PI_CONTEXT, PI_MAX_TOKENS, PI_RAPID_MODEL, PI_RAPID_PORT, PI_RAPID_BASE_URL
  PI_PROFILE=normal|deep-reasoning, PI_MIN_FREE_GB, PI_MIN_MEMORY_GB
  PI_SKIP_RUNTIME=1 (write/test configuration without loading LaunchAgent)
EOF_USAGE
}

PI_PROFILE="${PI_PROFILE:-normal}"
PI_THINKING="${PI_THINKING:-off}"
case "${1:-}" in
  "") ;;
  --deep-reasoning) PI_PROFILE=deep-reasoning ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
case "$PI_PROFILE:$PI_THINKING" in
  normal:off|deep-reasoning:off|deep-reasoning:on) ;;
  normal:on) PI_PROFILE=deep-reasoning ;;
  *) usage >&2; exit 2 ;;
esac

if [ -t 1 ] && [ -t 2 ]; then
  C_RESET=$(printf '\033[0m')
  C_DIM=$(printf '\033[2m')
  C_CYAN=$(printf '\033[36m')
  C_GREEN=$(printf '\033[32m')
  C_YELLOW=$(printf '\033[33m')
  C_RED=$(printf '\033[31m')
else
  C_RESET=''; C_DIM=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

elapsed() {
  now=$(date +%s)
  printf '%02dm%02ds' $(((now - START_TIME) / 60)) $(((now - START_TIME) % 60))
}

info() { printf '%s[%s]%s  %s\n' "$C_DIM" "$(elapsed)" "$C_RESET" "$*"; }
ok() { printf '%s[%s]%s  %s✓%s %s\n' "$C_DIM" "$(elapsed)" "$C_RESET" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[%s]%s  %s!%s %s\n' "$C_DIM" "$(elapsed)" "$C_RESET" "$C_YELLOW" "$C_RESET" "$*"; }
die() { printf '%s[%s]%s  %s✗%s %s\n' "$C_DIM" "$(elapsed)" "$C_RESET" "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
step() {
  STEP=$((STEP + 1))
  printf '\n%s[%02d]%s %s%s%s\n' "$C_CYAN" "$STEP" "$C_RESET" "$C_CYAN" "$*" "$C_RESET"
}

printf '\n%sPi + Rapid-MLX local coding setup%s\n' "$C_CYAN" "$C_RESET"
printf '%sLive installer output · elapsed time shown on every event%s\n' "$C_DIM" "$C_RESET"

step "Checking platform"
[ "$(uname -s)" = "Darwin" ] || die "macOS is required."
[ "$(uname -m)" = "arm64" ] || die "Apple Silicon is required."
CHECK_MIN_MEMORY_GB="${PI_MIN_MEMORY_GB:-40}"
CHECK_MIN_FREE_GB="${PI_MIN_FREE_GB:-20}"
MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || printf '0')"
MIN_MEM_BYTES=$((CHECK_MIN_MEMORY_GB * 1024 * 1024 * 1024))
[ "$MEM_BYTES" -ge "$MIN_MEM_BYTES" ] || die "At least ${CHECK_MIN_MEMORY_GB} GB unified memory is required (detected ${MEM_BYTES} bytes)."
FREE_KB="$(df -Pk . | awk 'NR==2 {print $4}')"
MIN_FREE_KB=$((CHECK_MIN_FREE_GB * 1024 * 1024))
[ "${FREE_KB:-0}" -ge "$MIN_FREE_KB" ] || die "Only $(( ${FREE_KB:-0} / 1024 / 1024 )) GB free; at least ${CHECK_MIN_FREE_GB} GB is required. Nothing was changed."
ok "Apple Silicon and memory check passed; disk headroom is $((FREE_KB / 1024 / 1024)) GB."

PI_PACKAGE="${PI_PACKAGE:-@earendil-works/pi-coding-agent}"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
LOCAL_AGENT_CONFIG_DIR="${LOCAL_AGENT_CONFIG_DIR:-$HOME/.config/local-agentic-dev}"
PI_PROVIDER_ID="${PI_PROVIDER_ID:-rapid-mlx}"
PI_PROVIDER_NAME="${PI_PROVIDER_NAME:-Rapid-MLX}"
PI_RAPID_PORT="${PI_RAPID_PORT:-8000}"
PI_RAPID_BASE_URL="${PI_RAPID_BASE_URL:-http://127.0.0.1:$PI_RAPID_PORT/v1}"
PI_RAPID_MODEL="${PI_RAPID_MODEL:-mlx-community/Qwen3.6-35B-A3B-nvfp4}"
PI_DEFAULT_PROVIDER="${PI_DEFAULT_PROVIDER:-$PI_PROVIDER_ID}"
PI_DEFAULT_MODEL="${PI_DEFAULT_MODEL:-$PI_RAPID_MODEL}"
PI_CONTEXT="${PI_CONTEXT:-98304}"
PI_MAX_TOKENS="${PI_MAX_TOKENS:-12288}"
PI_MIN_MEMORY_GB="${PI_MIN_MEMORY_GB:-40}"
PI_MIN_FREE_GB="${PI_MIN_FREE_GB:-20}"
PI_REQUIRED_VERSION="${PI_REQUIRED_VERSION:-0.84.1}"
PI_SKIP_RUNTIME="${PI_SKIP_RUNTIME:-0}"
PI_RAPID_LAUNCH_LABEL="${PI_RAPID_LAUNCH_LABEL:-com.local-agentic-dev.rapid-mlx}"
PI_RAPID_LAUNCH_AGENT="$HOME/Library/LaunchAgents/$PI_RAPID_LAUNCH_LABEL.plist"
PI_RAPID_LOG_DIR="$LOCAL_AGENT_CONFIG_DIR/logs"
MANIFEST="$LOCAL_AGENT_CONFIG_DIR/install-manifest"

manifest_set() {
  key="$1"; value="$2"
  mkdir -p "$LOCAL_AGENT_CONFIG_DIR"
  if [ -f "$MANIFEST" ] && grep -q "^${key}=" "$MANIFEST"; then
    tmp="$(mktemp)"
    grep -v "^${key}=" "$MANIFEST" > "$tmp"
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
    mv "$tmp" "$MANIFEST"
  else
    printf '%s=%s\n' "$key" "$value" >> "$MANIFEST"
  fi
}

backup_once() {
  file="$1"; backup="$file.pre-local-agentic-dev"
  if [ -f "$file" ] && [ ! -f "$backup" ]; then
    cp "$file" "$backup"
    ok "Backed up $file"
  fi
}

step "Checking required tools"
command -v rapid-mlx >/dev/null 2>&1 || die "Rapid-MLX is required. Install it with: brew install rapid-mlx"
command -v node >/dev/null 2>&1 || die "Node is required."
ok "Rapid-MLX and Node are available."

step "Checking Pi CLI"
if command -v pi >/dev/null 2>&1; then
  PI_VERSION="$(pi --version 2>/dev/null | head -1 | tr -d 'v')"
  if [ "$PI_VERSION" != "$PI_REQUIRED_VERSION" ]; then
    command -v npm >/dev/null 2>&1 || die "Pi ${PI_VERSION:-unknown} is stale; npm is required to install $PI_PACKAGE@$PI_REQUIRED_VERSION."
    info "Upgrading Pi from ${PI_VERSION:-unknown} to $PI_REQUIRED_VERSION..."
    npm install -g "$PI_PACKAGE@$PI_REQUIRED_VERSION"
  fi
  ok "Pi CLI ready: $(command -v pi) ($(pi --version 2>/dev/null | head -1))"
else
  command -v npm >/dev/null 2>&1 || die "npm is required to install $PI_PACKAGE."
  info "Installing $PI_PACKAGE@$PI_REQUIRED_VERSION with npm; package output follows..."
  npm install -g "$PI_PACKAGE@$PI_REQUIRED_VERSION"
  ok "Pi CLI installed."
fi
command -v pi >/dev/null 2>&1 || die "Pi CLI is not on PATH."

step "Preparing configuration directories"
mkdir -p "$PI_AGENT_DIR" "$LOCAL_AGENT_CONFIG_DIR" "$HOME/Library/LaunchAgents" "$PI_RAPID_LOG_DIR"
ok "Configuration directories ready."
backup_once "$PI_AGENT_DIR/models.json"
backup_once "$PI_AGENT_DIR/settings.json"

step "Writing Pi provider configuration"
export PI_AGENT_DIR PI_PROVIDER_ID PI_PROVIDER_NAME PI_RAPID_BASE_URL PI_RAPID_MODEL PI_DEFAULT_PROVIDER PI_DEFAULT_MODEL PI_CONTEXT PI_MAX_TOKENS
info "Model: $PI_RAPID_MODEL"
info "Context: $PI_CONTEXT tokens · output limit: $PI_MAX_TOKENS tokens"
node <<'EOF_NODE'
const fs = require('fs');
const path = require('path');

const dir = process.env.PI_AGENT_DIR;
const modelsPath = path.join(dir, 'models.json');
const settingsPath = path.join(dir, 'settings.json');
const model = process.env.PI_RAPID_MODEL;
const provider = process.env.PI_PROVIDER_ID;
const settings = fs.existsSync(settingsPath) ? JSON.parse(fs.readFileSync(settingsPath, 'utf8')) : {};
const models = fs.existsSync(modelsPath) ? JSON.parse(fs.readFileSync(modelsPath, 'utf8')) : {};

models.providers = {
  [provider]: {
    baseUrl: process.env.PI_RAPID_BASE_URL,
    api: 'openai-completions',
    apiKey: 'rapid-mlx',
    compat: {
      supportsDeveloperRole: false,
      supportsReasoningEffort: false,
      thinkingFormat: 'qwen-chat-template',
      maxTokensField: 'max_tokens'
    },
    models: [{
      id: model,
      name: `${process.env.PI_PROVIDER_NAME} - ${model}`,
      reasoning: true,
      contextWindow: Number(process.env.PI_CONTEXT),
      maxTokens: Number(process.env.PI_MAX_TOKENS),
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
    }]
  }
};

settings.defaultProvider = process.env.PI_DEFAULT_PROVIDER;
settings.defaultModel = process.env.PI_DEFAULT_MODEL;
settings.enabledModels = [process.env.PI_DEFAULT_MODEL];
settings.packages = (Array.isArray(settings.packages) ? settings.packages : [])
  .filter((pkg) => !pkg.includes('@ollama/pi-web-search'));
fs.writeFileSync(modelsPath, JSON.stringify(models, null, 2) + '\n');
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
EOF_NODE
ok "Pi provider and settings written."

step "Writing Rapid-MLX LaunchAgent"
if [ "$PI_PROFILE" = "deep-reasoning" ]; then
  RAPID_PROFILE_ARGS='<string>--reasoning</string>'
else
  RAPID_PROFILE_ARGS='<string>--no-thinking</string>'
fi
cat > "$PI_RAPID_LAUNCH_AGENT" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$PI_RAPID_LAUNCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v rapid-mlx)</string>
    <string>serve</string><string>$PI_RAPID_MODEL</string>
    <string>--host</string><string>127.0.0.1</string>
    <string>--port</string><string>$PI_RAPID_PORT</string>
    <string>--max-num-seqs</string><string>1</string>
    <string>--max-concurrent-requests</string><string>1</string>
    <string>--enable-auto-tool-choice</string>
    <string>--tool-call-parser</string><string>qwen3</string>
    $RAPID_PROFILE_ARGS
    <string>--max-tokens</string><string>$PI_MAX_TOKENS</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$PI_RAPID_LOG_DIR/rapid-mlx.log</string>
  <key>StandardErrorPath</key><string>$PI_RAPID_LOG_DIR/rapid-mlx.err.log</string>
</dict>
</plist>
EOF_PLIST
ok "LaunchAgent written: $PI_RAPID_LAUNCH_AGENT"

step "Recording install manifest"
manifest_set harness rapid-mlx
manifest_set pi_package "$PI_PACKAGE"
manifest_set pi_agent_dir "$PI_AGENT_DIR"
manifest_set pi_models "$PI_AGENT_DIR/models.json"
manifest_set pi_settings "$PI_AGENT_DIR/settings.json"
manifest_set pi_rapid_base_url "$PI_RAPID_BASE_URL"
manifest_set pi_rapid_port "$PI_RAPID_PORT"
manifest_set pi_rapid_model "$PI_RAPID_MODEL"
manifest_set pi_rapid_launch_agent "$PI_RAPID_LAUNCH_AGENT"
manifest_set pi_default_provider "$PI_DEFAULT_PROVIDER"
manifest_set pi_default_model "$PI_DEFAULT_MODEL"
manifest_set pi_context "$PI_CONTEXT"
manifest_set pi_max_tokens "$PI_MAX_TOKENS"
manifest_set pi_profile "$PI_PROFILE"
manifest_set pi_version "$PI_REQUIRED_VERSION"
ok "Install manifest updated."

if [ "$PI_SKIP_RUNTIME" = "1" ]; then
  warn "PI_SKIP_RUNTIME=1: configuration written; LaunchAgent was not loaded."
  printf '\n%sConfiguration complete.%s\n' "$C_GREEN" "$C_RESET"
  exit 0
fi

step "Restarting Rapid-MLX service"
info "Stopping any previous LaunchAgent instance..."
launchctl bootout "gui/$(id -u)" "$PI_RAPID_LAUNCH_AGENT" >/dev/null 2>&1 || true
sleep 1
if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$PI_RAPID_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  die "Port $PI_RAPID_PORT is already in use. Set PI_RAPID_PORT to a free dedicated port and rerun."
fi
info "Registering LaunchAgent..."
if launchctl bootstrap "gui/$(id -u)" "$PI_RAPID_LAUNCH_AGENT" >/dev/null 2>&1; then
  info "Kickstarting Rapid-MLX..."
  launchctl enable "gui/$(id -u)/$PI_RAPID_LAUNCH_LABEL" >/dev/null 2>&1 || true
  launchctl kickstart -k "gui/$(id -u)/$PI_RAPID_LAUNCH_LABEL" >/dev/null 2>&1 || true
  ok "Rapid-MLX LaunchAgent loaded."
  info "Waiting for the model server to become ready (up to 60 seconds)..."
  ready=false
  attempt=0
  while [ "$attempt" -lt 60 ]; do
    if curl -fsS --max-time 2 "$PI_RAPID_BASE_URL/models" >/dev/null 2>&1; then
      ready=true
      break
    fi
    attempt=$((attempt + 1))
    if [ -t 1 ]; then
      printf '\r%s[%s]%s  Loading model... %02ds elapsed' "$C_DIM" "$(elapsed)" "$C_RESET" "$attempt"
    elif [ $((attempt % 10)) -eq 0 ]; then
      info "Still waiting for Rapid-MLX (${attempt}s elapsed)..."
    fi
    sleep 1
  done
  [ -t 1 ] && printf '\n'
  if [ "$ready" = "true" ]; then
    ok "Rapid-MLX endpoint is ready: $PI_RAPID_BASE_URL"
  else
    warn "LaunchAgent loaded but endpoint is not ready yet. Check $PI_RAPID_LOG_DIR/rapid-mlx.err.log"
  fi
else
  warn "LaunchAgent plist created but could not be registered in this session: $PI_RAPID_LAUNCH_AGENT"
fi

printf '\n%sSetup complete in %s.%s\n' "$C_GREEN" "$(elapsed)" "$C_RESET"
printf '  Provider : %s\n' "$PI_DEFAULT_PROVIDER"
printf '  Model    : %s\n' "$PI_DEFAULT_MODEL"
printf '  Endpoint : %s\n' "$PI_RAPID_BASE_URL"
printf '  Port     : %s (loopback only; installer checks for conflicts)\n' "$PI_RAPID_PORT"
printf '  Launch   : %s\n' "$PI_RAPID_LAUNCH_AGENT"
printf '  Command  : pi --offline\n'
