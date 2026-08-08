# Pi + Rapid-MLX Local Coding Harness

[![Validate](https://github.com/IFAKA/local-agentic-dev/actions/workflows/validate.yml/badge.svg)](https://github.com/IFAKA/local-agentic-dev/actions/workflows/validate.yml)

An offline local coding-agent setup for Apple Silicon Macs: Pi uses Rapid-MLX
to run Qwen3.6-35B-A3B-NVFP4 entirely on-device. It is designed for an M4 Pro
with 48 GB unified memory and keeps inference on loopback with no cloud
fallbacks.

This project runs the `pi` coding agent through one local inference runtime: Rapid-MLX on Apple Silicon. There are no provider fallbacks in the supported setup.

- **Machine target:** Apple Silicon Mac with 48 GB unified memory
- **Runtime:** Rapid-MLX
- **Endpoint:** `http://127.0.0.1:8000/v1`
- **Port policy:** loopback-only port 8000; the installer refuses to start if it is occupied
- **Model:** `mlx-community/Qwen3.6-35B-A3B-nvfp4`
- **Pi command:** `pi --offline`
- **Context:** 98,304 tokens

## Why this project

Use this when you want a practical local coding agent with no API bill,
network dependency, or provider failover. Rapid-MLX supplies the MLX runtime;
Pi supplies the terminal coding-agent workflow; this repository connects them
with a single reproducible LaunchAgent configuration.

## Compatibility

| Component | Supported target |
| --- | --- |
| Hardware | Apple Silicon Mac, 48 GB unified memory recommended |
| Operating system | macOS |
| Agent | Pi `0.84.1` |
| Runtime | Rapid-MLX `0.12.x` or compatible |
| Model | `mlx-community/Qwen3.6-35B-A3B-nvfp4` |
| Network | Not required after dependencies and model are available |

The installer requires at least 40 GB unified memory and 20 GB free disk by
default. Use `./doctor.sh` to see which prerequisite is blocking readiness.

## Install

```sh
brew install rapid-mlx
./install.sh
```

The installer registers Rapid-MLX as a user LaunchAgent and starts it at login. To start or restart it manually:

```sh
scripts/serve-rapid-mlx-qwen36.sh
```

After installation or login, `pi --offline` is the only command needed.

The installer displays numbered phases, elapsed time, tool/configuration status, and live model-readiness progress. It remains non-interactive, so it can also be used from scripts or redirected logs.

Before installing, run the read-only readiness report:

```sh
./doctor.sh
```

The installer fails before writing anything when headroom is unsafe; adjust
`PI_MIN_FREE_GB` only for a controlled test. Existing Pi files are backed up
once. No Ollama, OpenCode, Aider, or cloud provider is installed or configured.

Verify it before launching Pi:

```sh
curl -sf http://127.0.0.1:8000/v1/models
pi -p --no-tools --offline "Reply with exactly: LOCAL_PI_OK"
```

Only Rapid-MLX needs to be running. Do not run multiple local model servers at once; they compete for unified memory.

## Configuration

The installer writes one provider to `~/.pi/agent/models.json` and selects it in `~/.pi/agent/settings.json`. Existing Pi configuration is backed up once before replacement.

Supported overrides:

```sh
PI_RAPID_PORT=18000 PI_RAPID_BASE_URL=http://127.0.0.1:18000/v1 ./install.sh
PI_RAPID_MODEL=mlx-community/Qwen3.6-35B-A3B-nvfp4 ./install.sh
PI_CONTEXT=98304 PI_MAX_TOKENS=12288 ./install.sh
```

Normal coding disables model thinking. Use `./install.sh --deep-reasoning` (or `PI_PROFILE=deep-reasoning` / `PI_THINKING=on`) when a session explicitly needs the Rapid-MLX reasoning profile; rerun the normal install to return to the default.

The selected 4-bit model is appropriate for this Mac’s 48 GB memory. Keep one server sequence for the single-user Pi workflow.

## Benchmarking

Run the project benchmark only while Rapid-MLX is serving:

```sh
scripts/benchmark-frontier.py --profile rapid-mlx --runs 3
```

The benchmark records visible-output correctness, tool-call success, latency,
decode throughput, 64K/98K/larger context probes, memory pressure, and
available disk under `bench/results/`. Large context probes can consume
substantial unified memory; check `./doctor.sh` first.

Historical Ollama/OpenCode measurements are retained only as archive material; they are not supported runtime paths or fallbacks.

## Troubleshooting

- Run `./doctor.sh` to separate hardware, disk, Pi version, Rapid-MLX, and server-readiness issues.
- If the endpoint is not ready, inspect `~/.config/local-agentic-dev/logs/rapid-mlx.err.log`.
- If port 8000 is occupied, set `PI_RAPID_PORT` and a matching `PI_RAPID_BASE_URL`, then rerun the installer.
- If a long-context probe fails, return to the default 98,304-token context and verify available disk and memory.
- `./uninstall.sh` removes only this harness’s LaunchAgent and restores Pi backups; it does not delete model caches or unrelated local tools.

## Project status

This project supports one local runtime path: Pi + Rapid-MLX. Contributions
that add cloud fallback providers or a second active model server are outside
the supported architecture. See [CONTRIBUTING.md](CONTRIBUTING.md) before
opening a pull request.

## Uninstall

```sh
./uninstall.sh
```

Uninstall stops and removes the Rapid-MLX LaunchAgent and restores the backed-up Pi configuration. It does not remove the Rapid-MLX Homebrew package or downloaded model cache.
