# Little Coder + Nail + Rapid-MLX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current Pi harness configuration with Little Coder using the locally cached Nail Qwen3.6-35B-A3B MLX model served by Rapid-MLX.

**Architecture:** Rapid-MLX will serve the local Nail model over loopback at `127.0.0.1:8000/v1`. Little Coder, which is Pi-based, will be installed as the user-facing coding agent and configured with the local OpenAI-compatible provider; the existing model cache and unrelated user tools remain untouched. The installer and uninstaller will manage only this project’s LaunchAgent, Little Coder provider configuration, and backups.

**Tech Stack:** macOS Apple Silicon, Rapid-MLX, Little Coder, Node.js/npm, LaunchAgent, local Hugging Face MLX model.

---

### Task 1: Replace runtime and client defaults

**Files:**
- Modify: `install.sh`
- Modify: `scripts/serve-rapid-mlx-qwen36.sh`
- Modify: `doctor.sh`
- Modify: `uninstall.sh`

Set the model to the explicit local Nail directory, install Little Coder instead of the bare Pi package, write Little Coder’s local provider configuration, and keep Rapid-MLX loopback-only. Preserve backups and avoid deleting the model cache.

### Task 2: Update documentation and operational commands

**Files:**
- Modify: `README.md`
- Modify: `docs/local-ai-workstation/README.md`
- Modify: `docs/local-ai-workstation/architecture.md`

Document the new three-part stack, the local model path, required Node/Rapid-MLX prerequisites, startup/verification commands, and the precise uninstall scope.

### Task 3: Validate without destructive cleanup

Run shell syntax checks, the read-only doctor, inspect generated configuration, and verify the Rapid-MLX command accepts the local model path. Only after these checks pass, run the installer to make the requested user-level setup changes and verify the local `/v1/models` endpoint and Little Coder launch path.
