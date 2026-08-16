# local-agent

Local coding-agent setup for Apple Silicon macOS:

```text
local-agent → vanilla Pi → Rapid-MLX → Qwen3.6 MLX model
```

## Install

```sh
git clone <repo>
cd local-agentic-dev
./install.sh
```

The installer installs Rapid-MLX and Pi, downloads the model, configures Pi, installs the adaptive-thinking extension, and installs the `local-agent` command. It is safe to run again.

## Use

```sh
local-agent
```

This starts Rapid-MLX when needed, opens Pi with the local model already selected, and stops the server when Pi exits.

## Optional diagnostics

```sh
local-agent status
local-agent logs
local-agent help
```

## Configuration

The canonical settings are in [`config/local-agent.conf`](config/local-agent.conf):

```text
model    unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit
endpoint http://127.0.0.1:8000/v1
context  98304
output   24576
```

Rapid-MLX uses the Qwen3.6-compatible `qwen3_coder_xml` tool parser and `qwen3` reasoning parser. The default 98,304-token context and 24,576-token output are intended for large, complex enterprise web repositories; reduce them if unified memory is tight. Serving stays single-sequence with a small admission queue so a long coding session remains responsive. Requests may contain up to 32 MiB of tool/project data and can run for up to 30 minutes. Speculative decoding/MTP is disabled for this checkpoint.

All runtime values in `config/local-agent.conf` accept environment overrides, for example `CONTEXT=32768 MAX_OUTPUT=8192 PI_THINKING_LEVEL=medium local-agent` for a lower-memory run. `PI_THINKING_LEVEL` defaults to `high` and can be set to `off`, `low`, `medium`, `high`, or `xhigh`. Pi also loads the `pi-adaptive-thinking` extension, which lets the model temporarily raise or lower the Pi thinking level through a native tool; its global configuration is `~/.pi/agent/adaptive-thinking.json`.

Pi configuration lives in `~/.pi/agent/`. Models are stored in the Hugging Face cache, normally `~/.cache/huggingface/hub/`. Logs and runtime state live in `~/.config/local-agentic-dev/`.

## Update

Run the installer again:

```sh
./install.sh
```

## Uninstall

```sh
./uninstall.sh
```

This removes project configuration and runtime state, restores Pi backups, and preserves downloaded models and installed packages.
