# Aider + Qwen 3.6 Local Setup

Local setup for the `aider` coding agent using a dedicated `llama-server` endpoint:

- **Machine:** Apple Silicon `Mac16,8`
- **Memory target:** 48 GB unified memory
- **Aider model:** `openai/qwen3.6-27b-reasoning`
- **Server:** `http://127.0.0.1:11435/v1`
- **Model file:** `Qwen3.6-27B-Claude-Opus-Reasoning-Distill.q6_k.gguf`
- **Default context:** `32768`

The installer reuses one shared GGUF across macOS users, so the same 21GB model file is not duplicated per account. It also disables the older `ollama.custom` LaunchAgent if present, because that legacy service starts a second `llama-server` on the same port.

## Install

```sh
curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
```

For local testing from a clone:

```sh
./install.sh
```

## Important: First Run

Run the installer first from the macOS user that already has the GGUF. On this machine it is currently:

```sh
/Users/faka/.ollama-pi-qwen36/Qwen3.6-27B-Claude-Opus-Reasoning-Distill.q6_k.gguf
```

The installer copies it into shared storage:

```sh
/Users/Shared/pi-qwen36/Qwen3.6-27B-Claude-Opus-Reasoning-Distill.q6_k.gguf
```

Then run the installer from the other macOS user. That second user will reuse the shared GGUF and create its own per-user Aider config and LaunchAgent.

## What Gets Installed

- `aider` CLI if it is not already installed
- `llama-server` via Homebrew `llama.cpp`
- `~/Library/LaunchAgents/com.faka.pi-qwen36.plist`
- `~/.config/local-agentic-dev/aider.conf.yml`
- `~/.config/local-agentic-dev/aider.env`
- `~/.local/bin/local-code` wrapper
- `~/.aider.conf.yml` so plain `aider` uses the local model by default
- `~/.config/local-agentic-dev/install-manifest`

Existing `~/.aider.conf.yml` is backed up before replacement. The installer removes the Pi CLI by default because this setup is Aider-first.

## Usage

```sh
aider
# or
local-code
```

The generated Aider config uses:

```text
provider: OpenAI-compatible llama.cpp
model: openai/qwen3.6-27b-reasoning
baseUrl: http://127.0.0.1:11435/v1
contextWindow: 32768
maxTokens: 8192
parallelSlots: 1
reasoning: off by default for lower transcript/context noise
config: ~/.config/local-agentic-dev/aider.conf.yml
```

## Options

Use a different shared model directory:

```sh
PI_SHARED_DIR=/Volumes/FastSSD/pi-qwen36 ./install.sh
```

Use a different model id:

```sh
PI_MODEL_ID=qwen3.6-27b-reasoning ./install.sh
```

Download the GGUF once if it is not already present locally:

```sh
PI_GGUF_URL=https://example.com/model.gguf ./install.sh
```

Tune for another machine:

```sh
PI_CONTEXT=16384 PI_PARALLEL=1 ./install.sh   # 24-32 GB machines
PI_CONTEXT=32768 PI_PARALLEL=1 ./install.sh   # 48 GB default
PI_CONTEXT=65536 PI_PARALLEL=1 ./install.sh   # 64 GB+ after testing
PI_DISABLE_LEGACY_AGENTS=false ./install.sh    # keep old LaunchAgents if you manage ports yourself
```

Use a larger context only if you have tested memory pressure:

```sh
PI_CONTEXT=65536 ./install.sh
```

The default stays at `32768` because it is conservative for a 27B Q6 model on a 48 GB Mac.

## Uninstall

```sh
./uninstall.sh
```

Uninstall removes generated configs and restores backups, but it keeps the shared GGUF by default so another macOS user is not broken.

## Device Tuning Notes

The installer is tuned for a 48 GB Apple Silicon Mac by default: Qwen 3.6 27B Q6, 32K context, 8K max output, and one llama.cpp server slot (`-np 1`). One slot is intentional for local coding because parallel slots multiply KV-cache pressure without helping a single Aider session.

Aider is configured through `~/.config/local-agentic-dev/aider.conf.yml`. To change models later, rerun the installer with `PI_MODEL_ID=... PI_MODEL_FILE=...` or edit that config once. You do not need to rewrite aliases or remember the full `aider --model ...` command. The server defaults to `LOCAL_AGENT_REASONING=off` because Aider stores chat history and visible thinking wastes context; use `LOCAL_AGENT_REASONING=on ./install.sh` only when you want a noisier reasoning profile.

## Benchmarking The Frontier

The installer default is a hypothesis, not proof. To measure the device-specific frontier, keep the local model server running and run:

```sh
scripts/benchmark-frontier.py --runs 3
```

The benchmark writes JSONL and CSV files under `bench/results/`. Compare profiles by changing one variable at a time:

```sh
PI_CONTEXT=16384 ./install.sh && scripts/benchmark-frontier.py --runs 3
PI_CONTEXT=32768 ./install.sh && scripts/benchmark-frontier.py --runs 3
PI_CONTEXT=65536 ./install.sh && scripts/benchmark-frontier.py --runs 3
```

For quant sweeps, install the same model family at Q4/Q5/Q6/Q8 or IQ variants, rerun the installer with `PI_MODEL_FILE=...`, and compare pass rate, median latency, prompt tok/s, decode tok/s, context, slots, and memory pressure. A profile is on the efficient frontier only if no other tested profile is both faster/lighter and at least as reliable on the same prompts and project tasks.
