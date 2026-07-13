# Local AI Workstation

Repo-local operating guide for continuous local coding-agent sessions on Apple Silicon.

## Single production path

LAD supports exactly one production path:

- Agent: OpenCode
- Runtime: Ollama
- OpenCode model id: `ollama/qwen3.6:35b-a3b-nvfp4`
- Ollama model id: `qwen3.6:35b-a3b-nvfp4`

There is no Aider fallback, no `north-mini-code` fallback, and no alternate small-model path. If OpenCode, Ollama, or the Qwen model is unavailable, LAD reports the problem instead of silently switching tools.

## Install

```bash
./docs/local-ai-workstation/install-lad.sh
```

The installer symlinks `docs/local-ai-workstation/lad` to `~/.local/bin/lad` and backs up any existing nonmatching target. When invoked from a git repository, the installed command targets that current repository unless `LAD_REPO_ROOT` is set.

## Basic flow

```bash
lad doctor
lad start my-task
lad ask "Implement the requested change."
lad test
lad diff
lad checkpoint
lad apply
lad stop
```

`start`, `ask`, `shell`, `test`, `diff`, `status`, and `checkpoint` operate on an isolated snapshot sandbox under `docs/local-ai-workstation/sessions/<name>`. The real repository is changed only by `lad apply`, which records the patch first and applies it with `git apply --3way`; it never commits.

## Commands

- `help`: prints command help.
- `doctor`: checks git, bash, OpenCode, Ollama, model presence, Ollama API reachability, and repository paths.
- `start [name]`: creates or resumes an isolated snapshot sandbox from the current branch's `HEAD` and stores the active session in `docs/local-ai-workstation/.lad/active-session`.
- `ask TEXT`: requires an active session, runs `opencode run --model ollama/qwen3.6:35b-a3b-nvfp4 TEXT` inside the session sandbox, captures a log under `results/lad/logs/`, then runs checks.
- `shell`: opens interactive OpenCode with the Qwen model inside the session sandbox. If the CLI rejects direct model arguments, LAD prints the exact manual `cd ... && opencode` command.
- `test`: runs available `just lint/test/build` recipes and JavaScript package `lint`, `test`, and `build` scripts only when present. It does not install dependencies and records skipped checks under `results/lad/checks/`.
- `diff`: prints the active session diff against its base commit.
- `status`: prints session metadata and git status.
- `checkpoint`: saves the current patch and metadata under `results/lad/checkpoints/`.
- `apply`: refuses a dirty real repo unless `LAD_ALLOW_DIRTY=1`, checkpoints the session patch, and applies it to the real repo with `git apply --3way`.
- `stop [--force]`: refuses to remove a session with uncheckpointed changes. Use `--force` to discard the session without checkpoint protection.
- `bench`: calls `benchmark-agent.sh` for OpenCode/Qwen only and rejects agent/model overrides.
- `offline-check`: verifies local CLI prerequisites, Qwen model availability, Ollama API reachability, fallback-free OpenCode config, and package-cache risk.
- `uninstall`: removes LAD state and sessions only. `--include-results` also removes LAD result logs; global software is never uninstalled.

## Generated paths

When used in this repository, LAD writes only under `docs/local-ai-workstation/`:

- State: `docs/local-ai-workstation/.lad/`
- Active session pointer: `docs/local-ai-workstation/.lad/active-session`
- Session sandboxs: `docs/local-ai-workstation/sessions/`
- Logs, checkpoints, and check records: `docs/local-ai-workstation/results/lad/`

## Offline policy

LAD avoids network installs. Package checks run only against already-present project dependencies and scripts. Benchmark reports must contain measured output, an explicit dry-run plan, or clearly marked placeholders; never publish guessed numbers.
