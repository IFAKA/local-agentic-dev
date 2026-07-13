# Local AI Workstation Architecture

## Purpose

Provide a reproducible repo-local harness for coding-agent sessions through one supported production path: OpenCode using Ollama-hosted `qwen3.6:35b-a3b-nvfp4`.

## System shape

```text
Developer terminal/editor
        |
        v
LAD harness
  docs/local-ai-workstation/lad
  state: docs/local-ai-workstation/.lad/
  active session: docs/local-ai-workstation/.lad/active-session
  sandboxs: docs/local-ai-workstation/sessions/
  results: docs/local-ai-workstation/results/lad/
        |
        v
OpenCode
  model: ollama/qwen3.6:35b-a3b-nvfp4
        |
        v
Ollama
  model: qwen3.6:35b-a3b-nvfp4
        |
        v
Apple Silicon workstation
```

## Non-goals

LAD does not provide fallback agents or fallback models. It does not run Aider, does not use `north-mini-code`, does not install packages, does not edit global OpenCode or Ollama configuration, and does not uninstall global software.

## Session isolation

`lad start [name]` creates or resumes `docs/local-ai-workstation/sessions/<name>` as a copied snapshot sandbox from the target repository current `HEAD`, then initializes an internal git baseline inside the session. Metadata is stored in `docs/local-ai-workstation/.lad/<name>.env`, and the active session pointer is `docs/local-ai-workstation/.lad/active-session`.

OpenCode runs inside the session sandbox with a session-local home at `<session>/.lad-home`. This keeps ordinary `ask` and `shell` execution away from the real repository and away from global mutable state.

## Mutation boundary

The real repository is protected by command design:

1. `start`, `ask`, `shell`, `test`, `diff`, `status`, and `checkpoint` never apply changes to the real repo.
2. `checkpoint` records session diff evidence under `docs/local-ai-workstation/results/lad/checkpoints/`.
3. `apply` is the only command that writes session changes to the real repo.
4. `apply` refuses unrelated dirty real-repo state unless `LAD_ALLOW_DIRTY=1` is set.
5. `apply` uses `git apply --3way` and never commits.
6. `stop` refuses to remove a session with uncheckpointed changes unless `--force` is supplied.

## Checks

`lad test` is best-effort and offline-safe. It runs `just lint`, `just test`, and `just build` when recipes exist and `just` is installed. It also detects `pnpm`, `yarn`, or `npm` and runs package `lint`, `test`, and `build` scripts only when the scripts exist. Missing recipes/scripts are recorded as skipped, not treated as harness failures.

## Offline readiness

`lad offline-check` validates local prerequisites without fetching anything: `git`, `bash`, `opencode`, `ollama`, the Qwen model in `ollama list`, Ollama API reachability, and OpenCode config free of fallback references such as `aider`, `north-mini-code`, `small_model`, or `fallback`. When a JavaScript project is detected, it reports dependency/cache risk rather than installing dependencies.

## Uninstall boundary

`lad uninstall` removes only LAD state and session sandboxs. `lad uninstall --include-results` also removes LAD result artifacts. Ollama, OpenCode, Homebrew, package managers, shell profiles, and models are never removed by LAD.
