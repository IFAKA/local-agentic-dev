#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOCAL_AGENT_REPO_ROOT="$ROOT"; export LOCAL_AGENT_REPO_ROOT
. "$ROOT/lib/config.sh"
pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is missing"; }
need curl; need node; need pi
mkdir -p "$STATE_DIR"
curl -fsS --max-time 5 "$BASE_URL/models" >"$STATE_DIR/models.json" || fail "/v1/models unavailable"
MODEL_ID="$MODEL_ID" node -e 'const fs=require("fs"),d=JSON.parse(fs.readFileSync(process.argv[1])); if (!d.data?.some(m=>m.id===process.env.MODEL_ID)) process.exit(1)' "$STATE_DIR/models.json" || fail "served model is not advertised"
pass "Rapid-MLX serves $MODEL_ID"
node -e 'const fs=require("fs"); fs.writeFileSync(process.argv[1], JSON.stringify({model:process.env.MODEL_ID,messages:[{role:"user",content:"Reply with exactly HEALTHY"}],max_tokens:16,temperature:0}))' "$STATE_DIR/request.json"
curl -fsS --max-time 60 "$BASE_URL/chat/completions" -H 'content-type: application/json' -H 'authorization: Bearer local' --data-binary "@$STATE_DIR/request.json" >"$STATE_DIR/completion.json" || fail "basic completion failed"
node -e 'const fs=require("fs"),d=JSON.parse(fs.readFileSync(process.argv[1])); if (!d.choices?.[0]?.message) process.exit(1)' "$STATE_DIR/completion.json" || fail "completion response was malformed"
pass "basic completion works"
node -e 'const fs=require("fs"); fs.writeFileSync(process.argv[1], JSON.stringify({model:process.env.MODEL_ID,messages:[{role:"user",content:"Call the list_files tool with path . now. Do not answer until the tool call is emitted."}],tools:[{type:"function",function:{name:"list_files",description:"List files",parameters:{type:"object",properties:{path:{type:"string"}},required:["path"]}}}],tool_choice:{type:"function",function:{name:"list_files"}},max_tokens:128,temperature:0}))' "$STATE_DIR/tool-request.json"
curl -fsS --max-time 60 "$BASE_URL/chat/completions" -H 'content-type: application/json' -H 'authorization: Bearer local' --data-binary "@$STATE_DIR/tool-request.json" >"$STATE_DIR/tool-response.json" || fail "tool-call completion failed"
node -e 'const fs=require("fs"),d=JSON.parse(fs.readFileSync(process.argv[1])),m=d.choices?.[0]?.message||{}; if (!(m.tool_calls?.length || /list_files/.test(m.content||""))) process.exit(1)' "$STATE_DIR/tool-response.json" || fail "tool call was not emitted"
pass "tool calling works"
pi --provider "$PI_PROVIDER" --model "$MODEL_ID" --list-models "$MODEL_ID" 2>&1 | grep -Fq "$MODEL_ID" || fail "Pi does not see $MODEL_ID"
pass "Pi sees the model"
pi --provider "$PI_PROVIDER" --model "$MODEL_ID:off" --no-session --tools ls --print 'Use the ls tool to list the current directory, then reply exactly PI_HEALTHY.' 2>&1 | grep -Fq 'PI_HEALTHY' || fail "Pi harmless tool-call task failed"
pass "Pi completed a harmless tool-call task"
if [ "${1:-}" = "--restart" ]; then
  "$ROOT/bin/local-agent" stop >/dev/null
  "$ROOT/bin/local-agent" start >/dev/null
  curl -fsS --max-time 5 "$BASE_URL/models" >/dev/null || fail "server did not restart cleanly"
  pass "server stops and restarts cleanly"
fi
count="$(find "$HOME/Library/LaunchAgents" -maxdepth 1 -name 'com.local-agentic-dev.*.plist' -print 2>/dev/null | wc -l | tr -d ' ')"
[ "$count" -eq 0 ] || fail "$count obsolete project LaunchAgent(s) remain"
pass "no duplicate project LaunchAgents"
printf '%s\n' 'Health check passed.'
