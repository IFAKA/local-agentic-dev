#!/usr/bin/env python3
"""Benchmark a local Pi/llama.cpp endpoint for device-specific frontier data.

This intentionally uses only the Python standard library so the installer remains
portable. It measures endpoint metadata, prompt/decode throughput, latency, and
simple deterministic quality checks. Run multiple times across quant/context/slot
profiles, then compare the generated CSV/JSONL files for Pareto choices.
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
from pathlib import Path
from typing import Any

PROMPTS = [
    {
        "name": "clean_short",
        "max_tokens": 32,
        "thinking": False,
        "messages": [
            {"role": "system", "content": "Be concise."},
            {"role": "user", "content": "Reply with exactly: ok"},
        ],
        "must_contain": "ok",
    },
    {
        "name": "typescript_review",
        "max_tokens": 384,
        "thinking": False,
        "messages": [
            {"role": "system", "content": "You are a strict TypeScript code reviewer. Be concise."},
            {
                "role": "user",
                "content": "Review this code for the most important bug only:\n\nfunction total(xs: number[]) { let sum = 0; xs.map(x => sum + x); return sum }",
            },
        ],
        "must_contain": "sum",
    },
    {
        "name": "agent_plan",
        "max_tokens": 512,
        "thinking": True,
        "messages": [
            {"role": "system", "content": "You are a local coding agent. Plan before editing."},
            {
                "role": "user",
                "content": "A Next.js page has a button that overflows on mobile. Give a 3-step implementation plan, no code.",
            },
        ],
        "must_contain": "mobile",
    },
]


def run(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return ""


def request_json(url: str, payload: dict[str, Any] | None = None, timeout: int = 600) -> dict[str, Any]:
    if payload is None:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    values = sorted(values)
    index = min(len(values) - 1, max(0, round((len(values) - 1) * p)))
    return values[index]


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark local Pi/llama.cpp endpoint")
    parser.add_argument("--base-url", default=os.environ.get("PI_BENCH_BASE_URL", "http://127.0.0.1:11435"))
    parser.add_argument("--model", default=os.environ.get("PI_BENCH_MODEL", "qwen3.6-27b-reasoning"))
    parser.add_argument("--runs", type=int, default=int(os.environ.get("PI_BENCH_RUNS", "3")))
    parser.add_argument("--out-dir", default=os.environ.get("PI_BENCH_OUT_DIR", "bench/results"))
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    jsonl_path = out_dir / f"{stamp}-{args.model}.jsonl"
    csv_path = out_dir / f"{stamp}-{args.model}.summary.csv"

    props = request_json(f"{base}/props")
    models = request_json(f"{base}/v1/models")
    hardware = {
        "machine": platform.machine(),
        "platform": platform.platform(),
        "cpu": run(["sysctl", "-n", "machdep.cpu.brand_string"]),
        "mem_bytes": run(["sysctl", "-n", "hw.memsize"]),
    }

    records: list[dict[str, Any]] = []
    with jsonl_path.open("w") as f:
        f.write(json.dumps({"type": "metadata", "hardware": hardware, "props": props, "models": models}) + "\n")
        for prompt in PROMPTS:
            for run_index in range(args.runs):
                payload = {
                    "model": args.model,
                    "messages": prompt["messages"],
                    "max_tokens": prompt["max_tokens"],
                    "temperature": 0.35,
                    "top_p": 0.9,
                    "top_k": 20,
                    "stream": False,
                    "chat_template_kwargs": {"enable_thinking": bool(prompt["thinking"]), "preserve_thinking": bool(prompt["thinking"])} ,
                }
                started = time.perf_counter()
                try:
                    response = request_json(f"{base}/v1/chat/completions", payload)
                    error = ""
                except urllib.error.HTTPError as exc:
                    response = {"error": exc.read().decode(errors="replace")}
                    error = str(exc)
                except Exception as exc:  # noqa: BLE001 - diagnostic script
                    response = {"error": repr(exc)}
                    error = repr(exc)
                elapsed = time.perf_counter() - started

                message = (((response.get("choices") or [{}])[0]).get("message") or {}) if isinstance(response, dict) else {}
                content = (message.get("content") or "") + "\n" + (message.get("reasoning_content") or "")
                timings = response.get("timings", {}) if isinstance(response, dict) else {}
                usage = response.get("usage", {}) if isinstance(response, dict) else {}
                record = {
                    "type": "run",
                    "prompt": prompt["name"],
                    "run_index": run_index,
                    "thinking": prompt["thinking"],
                    "elapsed_s": elapsed,
                    "ok": (not error) and (prompt["must_contain"].lower() in content.lower()),
                    "error": error,
                    "prompt_tokens": usage.get("prompt_tokens", 0),
                    "completion_tokens": usage.get("completion_tokens", 0),
                    "prompt_tps": timings.get("prompt_per_second", 0),
                    "decode_tps": timings.get("predicted_per_second", 0),
                    "model_path": props.get("model_path"),
                    "n_ctx": (props.get("default_generation_settings", {}).get("n_ctx") or props.get("default_generation_settings", {}).get("params", {}).get("n_ctx")),
                    "total_slots": props.get("total_slots"),
                }
                records.append(record)
                f.write(json.dumps(record) + "\n")
                print(json.dumps(record), flush=True)

    rows = []
    for name in sorted({r["prompt"] for r in records}):
        group = [r for r in records if r["prompt"] == name]
        rows.append({
            "prompt": name,
            "runs": len(group),
            "pass_rate": sum(1 for r in group if r["ok"]) / max(1, len(group)),
            "median_elapsed_s": statistics.median([r["elapsed_s"] for r in group]),
            "p90_elapsed_s": percentile([r["elapsed_s"] for r in group], 0.9),
            "median_prompt_tps": statistics.median([float(r["prompt_tps"] or 0) for r in group]),
            "median_decode_tps": statistics.median([float(r["decode_tps"] or 0) for r in group]),
            "n_ctx": group[0].get("n_ctx"),
            "total_slots": group[0].get("total_slots"),
            "model_path": group[0].get("model_path"),
        })

    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nWrote {jsonl_path}")
    print(f"Wrote {csv_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
