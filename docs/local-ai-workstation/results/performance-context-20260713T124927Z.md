# Ollama Context Performance Report

Generated: 2026-07-13T12:49:27Z UTC
Model: `qwen3.6:35b-a3b-nvfp4`
Prompt: short coding-agent reliability prompt

| context | wall_s | load_s | prompt_eval_count | prompt_eval_s | eval_count | eval_s | decode_tok_s | ollama_ps |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 32768 | 9.372 | 4.907 | 29 | 2.810 | 64 | 1.364 | 46.927 | `qwen3.6:35b-a3b-nvfp4    1b50c6fdc2d4    21 GB    100% GPU     32768      24 hours from now` |
| 65536 | 1.529 | 0.041 | 29 | 0.067 | 64 | 1.402 | 45.639 | `qwen3.6:35b-a3b-nvfp4    1b50c6fdc2d4    21 GB    100% GPU     32768      24 hours from now` |
| 131072 | 1.542 | 0.033 | 29 | 0.000 | 64 | 1.491 | 42.932 | `qwen3.6:35b-a3b-nvfp4    1b50c6fdc2d4    21 GB    100% GPU     32768      24 hours from now` |

## Notes
- This measures API-level generation, not full autonomous edit quality.
- Thermal, battery, and GPU counters require privileged powermetrics sampling on macOS and are not captured here.
