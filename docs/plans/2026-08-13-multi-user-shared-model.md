# Multi-User Shared Model Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a second macOS user clone the repository and run `./install.sh` without downloading or duplicating the existing Nail MLX model.

**Architecture:** Keep one physical model copy under `/Users/Shared/LLM-Models/`, while retaining the current user's existing Hugging Face-style path as a symlink for compatibility. The installer will automatically prefer an explicitly configured model, then the existing per-user cache, then the shared model path. User-specific Little Coder configuration and LaunchAgents remain separate.

**Tech Stack:** POSIX shell, macOS shared filesystem, Rapid-MLX, Little Coder.

---

### Task 1: Add shared-model discovery

**Files:**
- Modify: `install.sh`
- Modify: `doctor.sh`

Add a `SHARED_MODEL_DIR` default and resolve the model in this order: `NAIL_MODEL_DIR`, existing `$HOME/.cache/...` path, shared path. Ensure generated manifests record the resolved path.

### Task 2: Document the multi-user workflow

**Files:**
- Modify: `README.md`

Document that the model is shared once under `/Users/Shared/LLM-Models`, that each user still receives their own app configuration, and that Ollama uses a separate model store.

### Task 3: Migrate the current model without a duplicate

Move the existing model directory to the shared location, grant both users read/traverse access, and replace the original path with a symlink to the shared directory. Verify the model files and current Rapid-MLX endpoint afterward.

### Task 4: Verify fresh-user installation behavior

Run shell syntax checks and doctor checks using a temporary HOME/configuration tree while pointing at the shared model. Confirm no model download is attempted and that the generated Rapid-MLX command references the shared path.
