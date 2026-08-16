#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOCAL_AGENT_REPO_ROOT="$ROOT"; export LOCAL_AGENT_REPO_ROOT
. "$ROOT/lib/config.sh"
export MODEL_ID
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
node -e 'const fs=require("fs"); fs.writeFileSync(process.argv[1], JSON.stringify({model:process.env.MODEL_ID,messages:[{role:"user",content:"Call the list_files tool now with arguments exactly {\"path\":\".\"}. Do not answer until the tool call is emitted."}],tools:[{type:"function",function:{name:"list_files",description:"List files",parameters:{type:"object",properties:{path:{type:"string"}}}}}],tool_choice:{type:"function",function:{name:"list_files"}},max_tokens:128,temperature:0}))' "$STATE_DIR/tool-request.json"
tool_call_ok=0
attempt=1
while [ "$attempt" -le 3 ]; do
  http_code="$(curl -sS --max-time 90 -o "$STATE_DIR/tool-response.json" -w '%{http_code}' "$BASE_URL/chat/completions" -H 'content-type: application/json' -H 'authorization: Bearer local' --data-binary "@$STATE_DIR/tool-request.json" 2>"$STATE_DIR/tool-curl-error.log" || printf '000')"
  if [ "${http_code#2}" != "$http_code" ] && node -e 'const fs=require("fs"),d=JSON.parse(fs.readFileSync(process.argv[1])),m=d.choices?.[0]?.message||{}; if (!(m.tool_calls?.length || /list_files/.test(m.content||""))) process.exit(1)' "$STATE_DIR/tool-response.json"; then
    tool_call_ok=1
    break
  fi
  printf '[WARN] tool-call probe attempt %s/3 returned HTTP %s; retrying\n' "$attempt" "$http_code" >&2
  sed -n '1,3p' "$STATE_DIR/tool-curl-error.log" "$STATE_DIR/tool-response.json" >&2 || true
  attempt=$((attempt + 1))
  if [ "$attempt" -le 3 ]; then
    [ "$http_code" = 503 ] && sleep 10 || sleep 1
  fi
done
[ "$tool_call_ok" -eq 1 ] || fail "tool-call completion failed after 3 attempts"
pass "tool calling works"
pi --provider "$PI_PROVIDER" --model "$MODEL_ID" --list-models "$MODEL_ID" 2>&1 | grep -Fq "$MODEL_ID" || fail "Pi does not see $MODEL_ID"
pass "Pi sees the model"
pi_tool_ok=0
attempt=1
while [ "$attempt" -le 3 ]; do
  pi --provider "$PI_PROVIDER" --model "$MODEL_ID:off" --no-session --tools ls --print 'Use the ls tool to list the current directory, then reply exactly PI_HEALTHY.' >"$STATE_DIR/pi-health-response.log" 2>&1 || true
  if grep -Fq 'PI_HEALTHY' "$STATE_DIR/pi-health-response.log"; then
    pi_tool_ok=1
    break
  fi
  printf '[WARN] Pi tool-use probe attempt %s/3 did not reach PI_HEALTHY; retrying\n' "$attempt" >&2
  sed -n '1,8p' "$STATE_DIR/pi-health-response.log" >&2 || true
  attempt=$((attempt + 1))
  [ "$attempt" -le 3 ] && sleep 1
done
[ "$pi_tool_ok" -eq 1 ] || fail "Pi harmless tool-call task failed after 3 attempts"
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
