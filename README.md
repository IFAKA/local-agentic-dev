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

The installer installs Rapid-MLX and vanilla Pi, downloads the model, configures Pi, and installs the `local-agent` command. It is safe to run again.

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
context  32768
output   8192
```

Rapid-MLX uses the Qwen3.6-compatible `qwen3_coder_xml` tool parser and `qwen3` reasoning parser. Speculative decoding/MTP is disabled for this checkpoint.

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
