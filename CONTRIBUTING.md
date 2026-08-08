# Contributing

Thanks for helping improve the Pi + Rapid-MLX local coding harness.

## Before opening a pull request

Run the repository checks:

```sh
sh -n install.sh uninstall.sh doctor.sh scripts/serve-rapid-mlx-qwen36.sh
python3 -m py_compile scripts/benchmark-frontier.py
```

If you have a compatible Apple Silicon Mac, also run `./doctor.sh`, a Pi
offline smoke test, and the tool-call benchmark. Do not commit generated
`bench/results/` output, local configuration, credentials, or model caches.

## Scope

Keep the supported path local-only: Pi, Rapid-MLX, loopback networking, and
the documented Qwen3.6 model. Explain any change to defaults, context limits,
LaunchAgent behavior, or configuration backups in the pull request.

## Pull requests

Describe the user-visible change, include verification commands and results,
and call out any Apple Silicon or disk-space assumptions.
