# Pi + Qwen 3.6 Local Setup

Local setup for the `pi` coding agent using a dedicated `llama-server` endpoint:

- **Machine:** Apple Silicon `Mac16,8`
- **Memory target:** 48 GB unified memory
- **Pi model id:** `qwen3.6-27b-reasoning`
- **Server:** `http://127.0.0.1:11435/v1`
- **Model file:** `Qwen3.6-27B-Claude-Opus-Reasoning-Distill.q6_k.gguf`
- **Default context:** `32768`

The installer reuses one shared GGUF across macOS users, so the same 21GB model file is not duplicated per account.

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

Then run the installer from the other macOS user. That second user will reuse the shared GGUF and create its own per-user Pi config and LaunchAgent.

## What Gets Installed

- `pi` CLI via `@mariozechner/pi-coding-agent`
- `llama-server` via Homebrew `llama.cpp`
- `~/Library/LaunchAgents/com.faka.pi-qwen36.plist`
- `~/.pi/agent/settings.json`
- `~/.pi/agent/models.json`
- `~/.config/local-agentic-dev/install-manifest`

Existing Pi settings and model config are backed up before replacement.

## Usage

```sh
pi
```

The generated Pi config uses:

```text
provider: ollama
model: qwen3.6-27b-reasoning
baseUrl: http://127.0.0.1:11435/v1
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
