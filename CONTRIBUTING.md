# Contributing

Thanks for helping improve the Pi + Rapid-MLX local coding harness.

## Before opening a pull request

Run the repository checks:

```sh
sh -n install.sh uninstall.sh bin/local-agent lib/config.sh scripts/*.sh
node --check scripts/bench.mjs
```

The installer pins the adaptive-thinking extension to a known version. Review
third-party Pi extension source before changing that pin; Pi extensions execute
inside the agent process.

If you have a compatible Apple Silicon Mac, also run `./scripts/health-check.sh`
and `local-agent bench`. Do not commit generated
`bench/results/` output, local configuration, credentials, or model caches.

## Scope

Keep the supported path local-only: Pi, Rapid-MLX, loopback networking, and
the documented Qwen3.6 model. Keep runtime defaults in
`config/local-agent.conf`; do not add LaunchAgents or duplicate configuration.

## Pull requests

Describe the user-visible change, include verification commands and results,
and call out any Apple Silicon or disk-space assumptions.
