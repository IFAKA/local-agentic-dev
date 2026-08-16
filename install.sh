#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LOCAL_AGENT_REPO_ROOT="$ROOT"; export LOCAL_AGENT_REPO_ROOT
. "$ROOT/lib/config.sh"
die() { printf 'install: %s\n' "$*" >&2; exit 1; }
backup_once() { src="$1"; dst="$2"; [ -f "$src" ] || return 0; [ -e "$dst" ] || { mkdir -p "$(dirname "$dst")"; cp -p "$src" "$dst"; printf 'Backed up %s to %s\n' "$src" "$dst"; }; }

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || die 'Apple Silicon macOS is required.'
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"; [ "$MACOS_MAJOR" -ge 14 ] || die 'macOS 14 or newer is required.'
command -v brew >/dev/null 2>&1 || die 'Homebrew is required: https://brew.sh'
command -v node >/dev/null 2>&1 || brew install node
NODE_MAJOR="$(node --version | sed 's/^v//' | cut -d. -f1)"; [ "$NODE_MAJOR" -ge 22 ] || die "Node.js 22+ is required; found $(node --version)"
command -v curl >/dev/null 2>&1 || die 'curl is required.'

if brew list --formula rapid-mlx >/dev/null 2>&1; then brew upgrade rapid-mlx >/dev/null 2>&1 || true; else brew install rapid-mlx; fi
npm_rapid="$(command -v rapid-mlx 2>/dev/null || true)"
case "$npm_rapid" in "$HOME/.local/bin/rapid-mlx") uv tool uninstall rapid-mlx >/dev/null 2>&1 || true;; esac
npm list --global --depth=0 @earendil-works/pi-coding-agent >/dev/null 2>&1 && npm uninstall --global @earendil-works/pi-coding-agent >/dev/null || true
npm uninstall --global little-coder >/dev/null 2>&1 || true
npm install --global @mariozechner/pi-coding-agent@latest >/dev/null
command -v rapid-mlx >/dev/null 2>&1 || die 'Rapid-MLX installation did not provide rapid-mlx'
command -v pi >/dev/null 2>&1 || die 'Pi installation did not provide pi'

printf 'Downloading/checking model %s\n' "$MODEL_REPO"
RAPID_MLX_BIN="$(brew --prefix rapid-mlx)/bin/rapid-mlx"; export RAPID_MLX_BIN
"$RAPID_MLX_BIN" pull "$MODEL_REPO"

mkdir -p "$PI_AGENT_DIR" "$CONFIG_DIR/backups" "$STATE_DIR" "$LOG_DIR" "$BENCH_DIR" "$HOME/.local/bin"
backup_once "$PI_AGENT_DIR/models.json" "$CONFIG_DIR/backups/pi-models.json"
backup_once "$PI_AGENT_DIR/settings.json" "$CONFIG_DIR/backups/pi-settings.json"
backup_once "$HOME/.zshrc" "$CONFIG_DIR/backups/zshrc"

HOME_ZSHRC="$HOME/.zshrc" node <<'NODE'
const fs = require('fs');
const file = process.env.HOME_ZSHRC;
if (fs.existsSync(file)) {
  const lines = fs.readFileSync(file, 'utf8').split('\n'), out = [];
  let skip = null;
  for (const line of lines) {
    if (line.startsWith('# local-agentic-dev: make plain')) { skip = 'offline'; continue; }
    if (line.startsWith('# local-agentic-dev: Little Coder')) { skip = 'function'; continue; }
    if (skip === 'offline' && line === 'export PI_OFFLINE=1') { skip = null; continue; }
    if (skip === 'function' && line === '}') { skip = null; continue; }
    if (!skip) out.push(line);
  }
  fs.writeFileSync(file, out.join('\n'));
}
NODE
legacy_little="$HOME/.config/little-coder/models.json"
if [ -f "$legacy_little" ] && [ -f "$legacy_little.pre-local-agentic-dev" ]; then
  mv "$legacy_little" "$legacy_little.removed-local-agentic-dev"
  printf 'Removed obsolete Little Coder provider config\n'
fi

PI_AGENT_DIR="$PI_AGENT_DIR" BASE_URL="$BASE_URL" MODEL_ID="$MODEL_ID" MODEL_REPO="$MODEL_REPO" CONTEXT="$CONTEXT" MAX_OUTPUT="$MAX_OUTPUT" PI_PROVIDER="$PI_PROVIDER" node <<'NODE'
const fs = require('fs');
const path = require('path');
const env = process.env;
function read(file, fallback) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; } }
function atomic(file, value) { const tmp = `${file}.tmp-${process.pid}`; fs.writeFileSync(tmp, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 }); fs.renameSync(tmp, file); }
const dir = env.PI_AGENT_DIR, modelsFile = path.join(dir, 'models.json'), settingsFile = path.join(dir, 'settings.json');
const models = read(modelsFile, {}); models.providers ??= {};
models.providers[env.PI_PROVIDER] = { ...(models.providers[env.PI_PROVIDER] ?? {}), api: 'openai-completions', baseUrl: env.BASE_URL, apiKey: 'local', models: [{ id: env.MODEL_ID, name: env.MODEL_REPO, reasoning: true, input: ['text'], contextWindow: Number(env.CONTEXT), maxTokens: Number(env.MAX_OUTPUT), cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }] };
atomic(modelsFile, models);
const settings = read(settingsFile, {}); settings.defaultProvider = env.PI_PROVIDER; settings.defaultModel = env.MODEL_ID; settings.defaultThinkingLevel = 'off'; atomic(settingsFile, settings);
NODE

cleanup_legacy() {
  for label in com.local-agentic-dev.rapid-mlx com.local-agentic-dev.nemotron-rapid-mlx; do
    plist="$HOME/Library/LaunchAgents/$label.plist"
    [ -f "$plist" ] || continue
    launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
    rm -f "$plist"
    printf 'Removed obsolete LaunchAgent %s\n' "$label"
  done
}
cleanup_legacy
ln -sfn "$ROOT/bin/local-agent" "$HOME/.local/bin/local-agent"
chmod +x "$ROOT/bin/local-agent" "$ROOT/scripts/health-check.sh" "$ROOT/scripts/bench.sh"
PATH="$HOME/.local/bin:$PATH"; export PATH
"$HOME/.local/bin/local-agent" start
"$ROOT/scripts/health-check.sh" --restart
printf '\nInstalled. Ensure ~/.local/bin is on PATH, then use: local-agent status\n'
