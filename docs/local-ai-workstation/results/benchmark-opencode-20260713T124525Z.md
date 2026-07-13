# Local AI Workstation Benchmark Result

Generated: 20260713T124525Z UTC
Agent: opencode
Model: qwen3.6:35b-a3b-nvfp4
Default context target: 64K when supported
Status: completed
Exit code: 0
Elapsed wall seconds: 6
Raw output: benchmark-opencode-20260713T124525Z.raw.txt
Execution mode: measured --execute
Sandbox HOME: /Users/iskaypet/code/no-work/tools/local-agentic-dev/docs/local-ai-workstation/results/sandbox-home
Benchmark workspace: /Users/iskaypet/code/no-work/tools/local-agentic-dev/docs/local-ai-workstation/results/benchmark-workspaces/opencode-20260713T124525Z

## Prompt

```text
Inspect this repository and reply with OK only. Do not edit files.
```

## Command

```bash
opencode run --model ollama/qwen3.6:35b-a3b-nvfp4 Inspect\ this\ repository\ and\ reply\ with\ OK\ only.\ Do\ not\ edit\ files.
```

## Safety policy

Dry-run is the default. Measured execution requires --execute or LOCAL_AI_WORKSTATION_BENCHMARK_EXECUTE=1.
When measured execution is enabled, HOME, XDG_CONFIG_HOME, XDG_CACHE_HOME, XDG_STATE_HOME, and XDG_DATA_HOME are redirected under docs/local-ai-workstation/results/sandbox-home, and the agent runs from a copied benchmark workspace under docs/local-ai-workstation/results/benchmark-workspaces.
The Aider command intentionally omits auto-edit approval flags such as --yes.
If GNU timeout is unavailable on macOS, LOCAL_AI_WORKSTATION_BENCHMARK_TIMEOUT is documented but not enforced by this script.

## Metrics policy

Only measured values are recorded. Missing, unsupported, skipped, or failed commands are evidence and must not be converted into synthetic success metrics.

## Placeholder fields for later analysis

- Token throughput: MEASURED_RESULT_PENDING
- Peak memory pressure: MEASURED_RESULT_PENDING
- Task success classification: MEASURED_RESULT_PENDING
- Notes from human review: MEASURED_RESULT_PENDING
