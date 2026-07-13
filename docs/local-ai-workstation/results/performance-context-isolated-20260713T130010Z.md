# Ollama Isolated Context Performance Report

Generated: 2026-07-13T13:00:10Z UTC
Model: `qwen3.6:35b-a3b-nvfp4`
Method: `ollama stop` before each context request, then `/api/generate` with `num_ctx`.

| context_requested | wall_s | load_s | prompt_eval_count | prompt_eval_s | eval_count | eval_s | decode_tok_s | ollama_ps |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 32768 | 9.117 | 4.149 | 29 | 3.044 | 64 | 1.558 | 41.083 | `qwen3.6:35b-a3b-nvfp4    1b50c6fdc2d4    21 GB    100% GPU     32768      24 hours from now` |
| 65536 | 8.661 | 4.147 | 29 | 2.776 | 64 | 1.489 | 42.990 | `qwen3.6:35b-a3b-nvfp4    1b50c6fdc2d4    21 GB    100% GPU     65536      24 hours from now` |
| 131072 | 9.147 | 4.246 | 29 | 3.129 | 64 | 1.365 | 46.890 | `qwen3.6:35b-a3b-nvfp4    1b50c6fdc2d4    21 GB    100% GPU     131072     24 hours from now` |

## Recommendation
- Prefer 64K by default for agent work: it preserves the requested workflow and avoids unproven 128K overhead.
- Use 128K only for explicit large-repo reads after measuring real task success; do not enable it as default from this synthetic prompt alone.
