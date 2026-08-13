# Little Coder + Nail + Rapid-MLX

An offline local coding-agent setup for Apple Silicon Macs. Little Coder is the coding interface, Rapid-MLX is the local OpenAI-compatible MLX server, and Nail is the locally cached `Qwen3.6-35B-A3B` model.

```text
little-coder → http://127.0.0.1:8000/v1 → Rapid-MLX → Nail MLX model
```

The installer uses this existing model directory for the current user when
present:
`~/.cache/huggingface/hub/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX`.
If that path is absent, it automatically uses the shared model path:
`/Users/Shared/LLM-Models/Nail-Qwen3.6-35B-A3B-MLX`.

## Install

```sh
./doctor.sh
./install.sh
little-coder
```

The configured model handle is `rapid-mlx/nail-qwen3.6-35b-a3b`.

The installer also configures bare `little-coder` to start interactive
sessions with thinking off. Little Coder currently forces medium thinking in
its launcher unless an explicit level is supplied; use `little-coder
--thinking medium` or `little-coder --thinking high` for deeper reasoning.

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

For multiple macOS users, keep one physical model copy at
`/Users/Shared/LLM-Models/Nail-Qwen3.6-35B-A3B-MLX`. Each user runs the same
installer and gets separate Little Coder configuration and a separate
LaunchAgent, while Rapid-MLX reads the shared model. Set
`NAIL_SHARED_MODEL_DIR` to use another shared location.

The installer reuses a working shared Rapid-MLX installation at
`/Users/Shared/LLM-Tools/rapid-mlx/bin` when available. If that installation
belongs to another user or cannot run for the current user, the installer
automatically installs a user-local copy. Little Coder is installed per user
because its CLI configuration and shell integration are user-specific.

Ollama does not automatically discover or reuse MLX/Hugging Face model files;
its model store and format are separate.

Little Coder’s provider file is written to `~/.config/little-coder/models.json`. The generated LaunchAgent and logs live under `~/.config/local-agentic-dev/`.

Nail’s model card recommends temperature 0.7 for agentic coding. Rapid-MLX is started with thinking disabled for normal coding. The model’s native context is 262,144 tokens; this harness defaults to 98,304 to leave memory headroom.

## Measured benchmark baseline

These are measured results from the supported setup on a MacBook Pro with an
M4 Pro and 48 GB unified memory. They are a practical reference for this
device, not a guaranteed minimum for every Mac.

| Test | Result |
| --- | ---: |
| Short answer | 0.7 s |
| Review code | 2.2 s / 47 tok/s |
| Make a plan | 2.5 s / 49 tok/s |
| Use a tool | 1.5 s / 14 tok/s |
| Readiness smoke test | 8/8 passed |
| 64K context response | 1m 57s |
| 98K context response | 3m 44s |

Short replies include startup time, and tool-use speed is lower because it
includes tool-call overhead. Results vary with context size, temperature,
background workloads, and Rapid-MLX version.

## Uninstall

```sh
./uninstall.sh
```

This removes only the generated LaunchAgent and Little Coder provider file. It keeps the Nail model cache and the Rapid-MLX/Little Coder packages.

## References

- [Little Coder](https://github.com/itayinbarr/little-coder)
- [Rapid-MLX](https://github.com/raullenchai/Rapid-MLX)
- [Nail model card](https://huggingface.co/peculiar-ragdoll/Nail-Qwen3.6-35B-A3B-MLX)
