# Offline Checklist

Use this checklist before depending on the workstation without network access.

## Models

- [ ] `qwen3.6:35b-a3b-nvfp4` is available locally in Ollama.
- [ ] The model can answer a short local prompt without network access.
- [ ] 64K context is supported or the effective lower context limit is documented.

## Agents

- [ ] OpenCode is installed and can target the local Ollama endpoint.

## Inspection tools

- [ ] Ghostty launches without network dependencies.
- [ ] tmux session creation works.
- [ ] zsh startup does not block on network resources.
- [ ] Neovim opens the repository without plugin-install prompts blocking inspection.

## Repo-local evidence

- [ ] `collect-versions.sh` has produced a current report.
- [ ] `benchmark-agent.sh` dry-run plans clearly mark pending measurements as `MEASURED_RESULT_PENDING`.
- [ ] `benchmark-agent.sh --execute` has produced measured output for OpenCode from the sandbox workspace.
- [ ] Placeholder values remain clearly marked as `MEASURED_RESULT_PENDING` where measurements are not available.

## Operator notes

- [ ] External update commands were reviewed before execution.
- [ ] External rollback commands were reviewed before execution.
- [ ] No repository script wrote to user home configuration or global tool state.
