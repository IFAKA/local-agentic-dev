# Local AI Workstation Benchmark Result

Generated: 20260713T152931Z UTC
Agent: opencode
Model: qwen3.6:35b-a3b-nvfp4
Default context target: 64K when supported
Status: dry-run-plan
Exit code: MEASURED_RESULT_PENDING
Elapsed wall seconds: MEASURED_RESULT_PENDING
Raw output: benchmark-opencode-20260713T152931Z.raw.txt
Execution mode: dry-run plan
Sandbox HOME: MEASURED_RESULT_PENDING
Benchmark workspace: MEASURED_RESULT_PENDING

## Prompt

~~~text
Explain the repository purpose in three concise bullets using only local context.
~~~

## Command

~~~bash
opencode run --model ollama/qwen3.6:35b-a3b-nvfp4 Explain\ the\ repository\ purpose\ in\ three\ concise\ bullets\ using\ only\ local\ context.
~~~

## Safety policy

Dry-run is the default. Measured execution requires --execute or LOCAL_AI_WORKSTATION_BENCHMARK_EXECUTE=1.
When measured execution is enabled, HOME, XDG_CONFIG_HOME, XDG_CACHE_HOME, XDG_STATE_HOME, and XDG_DATA_HOME are redirected under docs/local-ai-workstation/results/sandbox-home, and OpenCode runs from a copied benchmark workspace under docs/local-ai-workstation/results/benchmark-workspaces.
If GNU timeout is unavailable on macOS, LOCAL_AI_WORKSTATION_BENCHMARK_TIMEOUT is documented but not enforced by this script.

## Metrics policy

Only measured values are recorded. Missing, unsupported, skipped, or failed commands are evidence and must not be converted into synthetic success metrics.

## Placeholder fields for later analysis

- Token throughput: MEASURED_RESULT_PENDING
- Peak memory pressure: MEASURED_RESULT_PENDING
- Task success classification: MEASURED_RESULT_PENDING
- Notes from human review: MEASURED_RESULT_PENDING
