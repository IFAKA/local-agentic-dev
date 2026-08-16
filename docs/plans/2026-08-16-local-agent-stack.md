# Local Agent Stack Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make this repository the reproducible source of truth for a vanilla Pi + Rapid-MLX Qwen3.6 coding-agent stack on Apple Silicon macOS.

**Architecture:** One shell configuration file defines the model, endpoint, context, output, paths, and parser settings. A repository-owned `local-agent` CLI owns explicit server lifecycle through a PID file and logs; it does not install launchd or another daemon. The installer installs dependencies, pulls the model, merges Pi's supported `models.json` and `settings.json` entries with backups, installs the CLI, and runs health verification.

**Tech Stack:** POSIX shell, macOS `launchctl` only for safe cleanup, Homebrew, npm, Rapid-MLX OpenAI-compatible HTTP API, vanilla Pi custom provider configuration, curl, jq when available.

---

### Task 1: Define the canonical runtime configuration

**Files:**
- Create: `config/local-agent.conf`
- Create: `lib/config.sh`

Write the one canonical set of values: target HF repo, served model ID, loopback host/port, context 32768, max output 8192, `qwen3_coder_xml`, `qwen3`, and project-owned state/config/log/PID paths. Allow deliberate environment overrides without duplicating defaults elsewhere.

### Task 2: Implement explicit lifecycle and status commands

**Files:**
- Create: `bin/local-agent`
- Create: `scripts/health-check.sh`
- Modify: `install.sh`
- Modify: `uninstall.sh`

Implement `start`, `stop`, `status`, `logs`, `bench`, and `pi`. Track only the PID started by this CLI, validate process identity before stopping it, use atomic PID/state writes, and report model, endpoint, context, health, and cheap memory data. Health must exercise models, completion, tool-call JSON, Pi model discovery, Pi tool use, and restart behavior.

### Task 3: Make installation idempotent and merge Pi configuration

**Files:**
- Modify: `install.sh`
- Modify: `README.md`

Check Apple Silicon/macOS and Node/npm/Homebrew/uv prerequisites, install/update Rapid-MLX and vanilla Pi, pull the target model through Rapid-MLX, back up user-owned Pi files once, merge only the project provider/model/default settings, install a stable `local-agent` command under `~/.local/bin`, and verify the result. Do not touch Little Coder, OpenCode, Codex, or shell configuration.

### Task 4: Remove obsolete repository harness material

**Files:**
- Delete: obsolete Little Coder/Nemotron scripts and archived OpenCode/Ollama workstation harness files
- Modify: `README.md`

Remove only repository components that contradict the requested stack. Keep historical benchmark result data only if it is clearly useful and label it as archival; preserve unrelated user changes in the worktree.

### Task 5: Verify repeatedly

Run syntax checks, installer dry checks where possible, the installer, health check, stop/start cycle, status, benchmark, and a second health check. Inspect the final diff and confirm no duplicate project services/processes exist.
