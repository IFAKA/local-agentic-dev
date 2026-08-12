# Little Coder + Nail + Rapid-MLX

An offline local coding-agent setup for Apple Silicon Macs. Little Coder is the coding interface, Rapid-MLX is the local OpenAI-compatible MLX server, and Nail is the locally cached `Qwen3.6-35B-A3B` model.

```text
little-coder → http://127.0.0.1:8000/v1 → Rapid-MLX → Nail MLX model
```

The installer uses this existing model directory by default:
`~/.cache/huggingface/hub/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX`.

## Install

```sh
./doctor.sh
./install.sh
little-coder
```

The configured model handle is `rapid-mlx/nail-qwen3.6-35b-a3b`.

```sh
curl -sf http://127.0.0.1:8000/v1/models
little-coder --list-models
rapid-mlx doctor
```

Little Coder requires Node.js 22.19+. Rapid-MLX is installed with Homebrew and is bound to loopback only through a user LaunchAgent.

## Configuration

```sh
NAIL_MODEL_DIR=/path/to/Nail-Qwen3.6-35B-A3B-MLX ./install.sh
NAIL_CONTEXT=131072 NAIL_MAX_TOKENS=32768 ./install.sh
RAPID_MLX_PORT=18000 RAPID_MLX_BASE_URL=http://127.0.0.1:18000/v1 ./install.sh
```

Little Coder’s provider file is written to `~/.config/little-coder/models.json`. The generated LaunchAgent and logs live under `~/.config/local-agentic-dev/`.

Nail’s model card recommends temperature 0.7 for agentic coding. Rapid-MLX is started with thinking disabled for normal coding. The model’s native context is 262,144 tokens; this harness defaults to 98,304 to leave memory headroom.

## Uninstall

```sh
./uninstall.sh
```

This removes only the generated LaunchAgent and Little Coder provider file. It keeps the Nail model cache and the Rapid-MLX/Little Coder packages.

## References

- [Little Coder](https://github.com/itayinbarr/little-coder)
- [Rapid-MLX](https://github.com/raullenchai/Rapid-MLX)
- [Nail model card](https://huggingface.co/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX)
