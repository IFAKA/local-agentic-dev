# local-agentic-dev

Local agentic coding — same workflow as Claude Code, 100% free using Ollama.

**Requires:** macOS Apple Silicon, 20GB+ free disk, Homebrew

## Install
```sh
curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
```

## Uninstall (zero trace)
```sh
curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/uninstall.sh | sh
```

## Models
| Model | Context | Role |
|-------|---------|------|
| qwen3-coder:30b-128k | 128K | Default — agentic coding |
| devstral-small-2:128k | 128K | Mistral coding |
| qwen3.5:27b-128k | 128K | General + code |
| llama3.2:3b-32k | 32K | Fast/lightweight |

## Usage
```sh
cd /your/project
opencode
```

## Same-machine second user
Switch to the other user and run the same install curl command.
Ollama models are already running — install takes ~2 minutes.
