import fs from "node:fs";
import os from "node:os";
import { execFileSync } from "node:child_process";

const e = process.env, started = performance.now();
const request = { model: e.MODEL_ID, messages: [{ role: "user", content: "Reply with exactly: benchmark ok" }], max_tokens: 32, temperature: 0 };
const response = await fetch(`${e.BASE_URL}/chat/completions`, { method: "POST", headers: { "content-type": "application/json", authorization: "Bearer local" }, body: JSON.stringify({ ...request, stream: true, stream_options: { include_usage: true } }) });
if (!response.ok) throw new Error(`completion failed: HTTP ${response.status} ${await response.text()}`);
const reader = response.body.getReader(), decoder = new TextDecoder(); let raw = "", firstByte = null, done = false;
while (!done) { const chunk = await reader.read(); done = chunk.done; if (chunk.value) { firstByte ??= performance.now(); raw += decoder.decode(chunk.value, { stream: !done }); } }
const elapsed = Math.max((performance.now() - started) / 1000, 0.001), ttftSeconds = Math.max(((firstByte ?? performance.now()) - started) / 1000, 0.001);
let usage = {};
for (const line of raw.split("\n")) { if (!line.startsWith("data: ") || line === "data: [DONE]") continue; try { const data = JSON.parse(line.slice(6)); if (data.usage) usage = data.usage; } catch {} }
let rapidVersion = "unknown", peakMemoryMiB = null;
try { rapidVersion = execFileSync(e.RAPID_MLX_BIN || "rapid-mlx", ["--version"], { encoding: "utf8" }).trim(); } catch {}
try { const pid = fs.readFileSync(e.PID_FILE, "utf8").trim(); peakMemoryMiB = Math.round(Number(execFileSync("ps", ["-p", pid, "-o", "rss="], { encoding: "utf8" }).trim()) / 1024); } catch {}
const promptTokens = Number(usage.prompt_tokens ?? 0), completionTokens = Number(usage.completion_tokens ?? 0), generationSeconds = Math.max(elapsed - ttftSeconds, 0.001);
const result = { timestamp: new Date().toISOString(), model_repo: e.MODEL_REPO, served_model: e.MODEL_ID, endpoint: e.BASE_URL, context: Number(e.CONTEXT), max_output: Number(e.MAX_OUTPUT), rapid_mlx: rapidVersion, macos: os.release(), machine: os.arch(), ttft_ms: Math.round(ttftSeconds * 1000), prompt_tokens: promptTokens, prompt_processing_tok_s: promptTokens / ttftSeconds, completion_tokens: completionTokens, generation_tok_s: completionTokens / generationSeconds, peak_memory_mib: peakMemoryMiB, token_counts_source: usage.completion_tokens == null ? "server did not return stream usage" : "server usage" };
const file = `${e.BENCH_DIR}/bench-${result.timestamp.replaceAll(/[:.]/g, "-")}.json`;
fs.writeFileSync(file, JSON.stringify(result, null, 2) + "\n"); console.log(JSON.stringify(result, null, 2)); console.log(`Saved ${file}`);
