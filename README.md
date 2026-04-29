# Pi Agent Local Setup

Local Ollama-based coding setup for the Pi agent workflow currently used on this Mac:

- **Machine:** Apple Silicon `Mac16,8`
- **Memory target:** 48 GB unified memory
- **Main model:** `qwen35-reasoning:27b-q6`
- **Quantization:** `Q6_K`
- **Default context:** `32768`
- **Tools:** OpenCode and Aider through Ollama's local OpenAI-compatible endpoint

The installer is designed to reuse one shared Ollama model cache across macOS users, so the same 20GB+ model blobs are not downloaded once per account.

## Install

After these changes are pushed to `main`, run:

```sh
curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
```

For local testing from a clone:

```sh
./install.sh
```

## Important: First Run

Run the installer first from the macOS user that already has the model installed. On this machine that model cache is currently:

```sh
/Users/faka/.ollama/models
```

The installer copies that cache into:

```sh
/Users/Shared/ollama-models
```

Then run the installer from the other macOS user. That second user will point Ollama at the same shared cache instead of downloading duplicate model blobs.

If Ollama was already running before install, restart Ollama once after install so it picks up:

```sh
OLLAMA_MODELS=/Users/Shared/ollama-models
```

## What Gets Installed

- `~/.config/opencode/opencode.json`
- `~/.aider.conf.yml`
- `~/.config/local-agentic-dev/install-manifest`
- Shared Ollama cache configuration via `launchctl setenv OLLAMA_MODELS`

Existing OpenCode and Aider configs are backed up before replacement.

## Usage

```sh
opencode
```

```sh
aider
```

The generated configs use:

```sh
qwen35-reasoning:27b-q6
```

as the main model and:

```sh
llama3.2:3b
```

as the small helper model.

## Options

Use a different shared model cache:

```sh
OLLAMA_MODELS_DIR=/Volumes/FastSSD/ollama-models ./install.sh
```

Use a different local model name:

```sh
PI_AGENT_MODEL=qwen3.6-reasoning:27b-q6 ./install.sh
```

Use a pullable upstream fallback if the local model does not already exist:

```sh
PI_AGENT_UPSTREAM_MODEL=batiai/qwen3.6-27b:q6 ./install.sh
```

Use a larger context only if you have tested memory pressure:

```sh
PI_AGENT_CONTEXT=65536 ./install.sh
```

The default stays at `32768` because that is the current working model configuration on this 48 GB Mac.

## Uninstall

```sh
./uninstall.sh
```

Uninstall removes generated configs and restores backups, but it keeps shared Ollama models by default so another macOS user is not broken.
