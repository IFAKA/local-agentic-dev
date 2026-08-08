#!/usr/bin/env python3
"""Benchmark OpenAI-compatible local chat endpoints for Pi provider choices.

Defaults target the sole Rapid-MLX Pi runtime. The script avoids llama.cpp-only
endpoints such as /props.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import platform
import statistics
import subprocess
import sys
import time
import urllib.error
import urllib.request
import shutil
from pathlib import Path
from typing import Any

PROFILES = {
    "rapid-mlx": {
        "base_url": "http://127.0.0.1:8000/v1",
        "model": "mlx-community/Qwen3.6-35B-A3B-nvfp4",
    },
}

PROMPTS = [
    {
        "name": "short_exact",
        "max_tokens": 256,
        "messages": [
            {"role": "system", "content": "Be concise. Do not include hidden reasoning."},
            {"role": "user", "content": "Reply with exactly: ok"},
        ],
        "must_contain": "ok",
    },
    {
        "name": "typescript_bug_review",
        "max_tokens": 2048,
        "messages": [
            {"role": "system", "content": "You are a strict TypeScript code reviewer. Be concise."},
            {
                "role": "user",
                "content": (
                    "Review this code for the most important bug only:\n\n"
                    "function total(xs: number[]) { let sum = 0; xs.map(x => sum + x); return sum }"
                ),
            },
        ],
        "must_contain": "sum",
    },
    {
        "name": "three_step_plan",
        "max_tokens": 2048,
        "messages": [
            {"role": "system", "content": "You are a local coding agent. Give visible, actionable output."},
            {
                "role": "user",
                "content": "A Next.js page has a button that overflows on mobile. Give a 3-step implementation plan, no code.",
            },
        ],
        "must_contain": "mobile",
    },
    {
        "name": "tool_call",
        "max_tokens": 256,
        "messages": [
            {"role": "system", "content": "Use tools when appropriate. Do not answer before using the tool."},
            {"role": "user", "content": "Call get_weather for Madrid, then stop."},
        ],
        "tool": {
            "type": "function",
            "function": {"name": "get_weather", "description": "Get weather.",
                          "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}},
        },
    },
]


def safe_name(value: str) -> str:
    return "".join(ch if ch.isalnum() or ch in "._-" else "-" for ch in value).strip("-") or "model"


def run(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return ""


def request_json(url: str, payload: dict[str, Any] | None = None, timeout: int = 600) -> dict[str, Any]:
    headers = {"Accept": "application/json"}
    data = None
    method = "GET"
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
        method = "POST"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode()
        return json.loads(body) if body else {}


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * p)))
    return ordered[index]


def extract_error(response: Any, transport_error: str) -> str:
    if transport_error:
        return transport_error
    if not isinstance(response, dict):
        return "non_json_response"
    err = response.get("error")
    if isinstance(err, dict):
        return str(err.get("message") or err)
    if err:
        return str(err)
    return ""


def is_missing_model(error: str, response: Any) -> bool:
    text = error
    if isinstance(response, dict):
        text += " " + json.dumps(response, sort_keys=True)
    lowered = text.lower()
    markers = ["model not found", "not found", "does not exist", "unknown model", "pull the model"]
    return any(marker in lowered for marker in markers)


def visible_content(response: Any) -> str:
    if not isinstance(response, dict):
        return ""
    choices = response.get("choices") or []
    if not choices:
        return ""
    message = choices[0].get("message") or {}
    parts = [message.get("content") or ""]
    # Some servers expose reasoning separately; record it, but do not let hidden
    # reasoning mask an empty user-visible answer.
    visible = "\n".join(part for part in parts if part)
    return visible.strip()


def usage_tokens(response: Any) -> tuple[int, int]:
    if not isinstance(response, dict):
        return 0, 0
    usage = response.get("usage") or {}
    return int(usage.get("prompt_tokens") or 0), int(usage.get("completion_tokens") or 0)


def tool_call_success(response: Any) -> bool:
    if not isinstance(response, dict) or not response.get("choices"):
        return False
    message = response["choices"][0].get("message") or {}
    return any((call.get("function") or {}).get("name") == "get_weather" for call in (message.get("tool_calls") or []))


def host_snapshot() -> dict[str, Any]:
    disk = shutil.disk_usage(Path.cwd())
    return {"available_disk_bytes": disk.free, "memory_pressure": run(["memory_pressure"])[:2000]}


def decode_tps(response: Any, completion_tokens: int, elapsed_s: float) -> float:
    if isinstance(response, dict):
        timings = response.get("timings") or {}
        for key in ("predicted_per_second", "decode_tps", "completion_tokens_per_second"):
            value = timings.get(key)
            if value:
                return float(value)
        usage = response.get("usage") or {}
        value = usage.get("completion_tokens_per_second")
        if value:
            return float(value)
    if completion_tokens > 0 and elapsed_s > 0:
        return completion_tokens / elapsed_s
    return 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark OpenAI-compatible local chat endpoints")
    parser.add_argument("--profile", choices=sorted(PROFILES), default=os.environ.get("PI_BENCH_PROFILE", "rapid-mlx"))
    parser.add_argument("--base-url", default=os.environ.get("PI_BENCH_BASE_URL"))
    parser.add_argument("--model", default=os.environ.get("PI_BENCH_MODEL"))
    parser.add_argument("--runs", type=int, default=int(os.environ.get("PI_BENCH_RUNS", "3")))
    parser.add_argument("--out-dir", default=os.environ.get("PI_BENCH_OUT_DIR", "bench/results"))
    parser.add_argument("--timeout", type=int, default=int(os.environ.get("PI_BENCH_TIMEOUT", "600")))
    parser.add_argument("--contexts", default=os.environ.get("PI_BENCH_CONTEXTS", "65536,98304,131072"), help="Comma-separated context probe sizes")
    args = parser.parse_args()

    profile = PROFILES[args.profile]
    base = (args.base_url or profile["base_url"]).rstrip("/")
    model = args.model or profile["model"]

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    stem = f"{stamp}-{args.profile}-{safe_name(model)}"
    jsonl_path = out_dir / f"{stem}.jsonl"
    csv_path = out_dir / f"{stem}.summary.csv"

    hardware = {
        "machine": platform.machine(),
        "platform": platform.platform(),
        "cpu": run(["sysctl", "-n", "machdep.cpu.brand_string"]),
        "mem_bytes": run(["sysctl", "-n", "hw.memsize"]),
        "initial_host": host_snapshot(),
    }
    try:
        models = request_json(f"{base}/models", timeout=args.timeout)
        models_error = ""
    except Exception as exc:  # noqa: BLE001 - diagnostic script
        models = {}
        models_error = repr(exc)

    records: list[dict[str, Any]] = []
    with jsonl_path.open("w") as f:
        f.write(json.dumps({
            "type": "metadata",
            "profile": args.profile,
            "base_url": base,
            "model": model,
            "hardware": hardware,
            "models": models,
            "models_error": models_error,
            "context_targets": [int(value) for value in args.contexts.split(",") if value.strip()],
        }) + "\n")
        for prompt in PROMPTS:
            for run_index in range(args.runs):
                payload = {
                    "model": model,
                    "messages": prompt["messages"],
                    "max_tokens": prompt["max_tokens"],
                    "temperature": 0.2,
                    "top_p": 0.9,
                    "stream": False,
                }
                if prompt.get("tool"):
                    payload["tools"] = [prompt["tool"]]
                    payload["tool_choice"] = "auto"
                started = time.perf_counter()
                try:
                    response = request_json(f"{base}/chat/completions", payload, timeout=args.timeout)
                    transport_error = ""
                except urllib.error.HTTPError as exc:
                    response = {"error": exc.read().decode(errors="replace")}
                    transport_error = f"HTTP {exc.code} {exc.reason}"
                except Exception as exc:  # noqa: BLE001 - diagnostic script
                    response = {"error": repr(exc)}
                    transport_error = repr(exc)
                elapsed = time.perf_counter() - started

                content = visible_content(response)
                error = extract_error(response, transport_error)
                prompt_tokens, completion_tokens = usage_tokens(response)
                empty_visible_output = not content.strip()
                missing_model = is_missing_model(error, response)
                is_tool_prompt = bool(prompt.get("tool"))
                tool_ok = tool_call_success(response)
                record = {
                    "type": "run",
                    "profile": args.profile,
                    "base_url": base,
                    "model": model,
                    "prompt": prompt["name"],
                    "run_index": run_index,
                    "elapsed_s": round(elapsed, 6),
                    "ok": (not error) and (tool_ok if is_tool_prompt else (not empty_visible_output and prompt["must_contain"].lower() in content.lower())),
                    "visible_output_correct": (not is_tool_prompt) and (not empty_visible_output) and (prompt.get("must_contain", "").lower() in content.lower()),
                    "tool_call_success": tool_ok,
                    "empty_visible_output": empty_visible_output,
                    "missing_model": missing_model,
                    "error": error,
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "decode_tps": round(decode_tps(response, completion_tokens, elapsed), 3),
                    "visible_chars": len(content),
                }
                records.append(record)
                f.write(json.dumps(record) + "\n")
                print(json.dumps(record), flush=True)

        # Exercise the 64K, default 98K, and larger-context paths with a local
        # deterministic payload. This records real acceptance behavior instead
        # of inferring it from a server-advertised maximum.
        for context_target in [int(value) for value in args.contexts.split(",") if value.strip()]:
            filler = "context-probe " * max(1, (context_target * 4) // 14)
            payload = {"model": model, "messages": [{"role": "user", "content": filler + " Reply exactly CONTEXT_OK."}], "max_tokens": 32, "temperature": 0, "stream": False}
            started = time.perf_counter()
            try:
                response = request_json(f"{base}/chat/completions", payload, timeout=args.timeout)
                transport_error = ""
            except Exception as exc:  # noqa: BLE001 - diagnostic script
                response = {"error": repr(exc)}
                transport_error = repr(exc)
            elapsed = time.perf_counter() - started
            content = visible_content(response)
            error = extract_error(response, transport_error)
            prompt_tokens, completion_tokens = usage_tokens(response)
            record = {
                "type": "context_probe", "context_target": context_target,
                "prompt_tokens": prompt_tokens, "completion_tokens": completion_tokens,
                "elapsed_s": round(elapsed, 6), "ok": (not error) and ("context_ok" in content.lower()),
                "empty_visible_output": not content.strip(), "error": error,
                "available_disk_bytes_after": host_snapshot()["available_disk_bytes"],
                "decode_tps": round(decode_tps(response, completion_tokens, elapsed), 3),
            }
            records.append(record)
            f.write(json.dumps(record) + "\n")
            print(json.dumps(record), flush=True)

    rows = []
    for name in sorted({r["prompt"] for r in records if r["type"] == "run"}):
        group = [r for r in records if r["type"] == "run" and r["prompt"] == name]
        rows.append({
            "profile": args.profile,
            "base_url": base,
            "model": model,
            "prompt": name,
            "runs": len(group),
            "pass_rate": sum(1 for r in group if r["ok"]) / max(1, len(group)),
            "empty_visible_outputs": sum(1 for r in group if r["empty_visible_output"]),
            "missing_model_errors": sum(1 for r in group if r["missing_model"]),
            "median_elapsed_s": statistics.median([float(r["elapsed_s"]) for r in group]),
            "p90_elapsed_s": percentile([float(r["elapsed_s"]) for r in group], 0.9),
            "median_decode_tps": statistics.median([float(r["decode_tps"] or 0) for r in group]),
            "tool_call_successes": sum(1 for r in group if r.get("tool_call_success")),
        })

    for target in sorted({r["context_target"] for r in records if r["type"] == "context_probe"}):
        group = [r for r in records if r.get("context_target") == target]
        rows.append({
            "profile": args.profile, "base_url": base, "model": model,
            "prompt": f"context_{target}", "runs": len(group),
            "pass_rate": sum(1 for r in group if r["ok"]) / max(1, len(group)),
            "empty_visible_outputs": sum(1 for r in group if r["empty_visible_output"]),
            "missing_model_errors": 0,
            "median_elapsed_s": statistics.median([float(r["elapsed_s"]) for r in group]),
            "p90_elapsed_s": percentile([float(r["elapsed_s"]) for r in group], 0.9),
            "median_decode_tps": statistics.median([float(r["decode_tps"] or 0) for r in group]),
            "tool_call_successes": 0,
        })

    if rows:
        with csv_path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)

    print(f"\nWrote {jsonl_path}")
    print(f"Wrote {csv_path}")

    failed = [r for r in records if not r["ok"]]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
