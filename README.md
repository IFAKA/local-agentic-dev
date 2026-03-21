# 🚀 Local Agentic Dev (2026 "Efficient Frontier" Setup)

A high-performance, **100% local**, and free agentic coding setup optimized for Apple Silicon (M4 Pro/Max). Achieve "Claude Opus" level reasoning without API costs or data leaks.

## 📊 The "Efficient Frontier" Research (March 2026)

This setup is based on quantitative research for the **Mac16,8 (M4 Pro)** architecture:
- **Bandwidth Utilization:** Maximizes the 273 GB/s bandwidth of the M4 Pro.
- **RAM Optimization:** Specifically tuned for **48GB Unified Memory** setups.
- **Intelligence Frontier:** Uses **Q6_K (6-bit)** quantization—the mathematical "sweet spot" where you get 98% of FP16 reasoning with 50% less RAM usage.

### Benchmarks (M4 Pro @ 48GB)
| Model | Param | Quant | Context | Speed (TPS) |
|-------|-------|-------|---------|-------------|
| **Qwen-3-Coder** | 32B | **Q6_K** | 131K | **~22 t/s** |
| **DeepSeek-R1** | 32B | **Q6_K** | 65K | **~20 t/s** |

---

## 🛠️ Components
- **Inference:** [Ollama](https://ollama.com) (Local Llama.cpp backend)
- **Agent:** [OpenCode](https://github.com/anomalyco/opencode) (Autonomous Architect)
- **Pair-Programmer:** [Aider](https://aider.chat) (Surgical Edits)
- **Context:** [MCP](https://modelcontextprotocol.io) (Model Context Protocol support)

## 📥 Install
Run the hardware-aware installer:
```sh
curl -sSL https://raw.githubusercontent.com/IFAKA/local-agentic-dev/main/install.sh | sh
```

## 🚀 Usage
### 1. Autonomous Building (The "Big Guy" Workflow)
```sh
opencode --model qwen3-coder:32b-q6_K
```
*Best for: Starting projects from zero, adding large features, 10+ file edits.*

### 2. Surgical Pair-Programming
```sh
aider --model ollama/qwen3-coder:32b-q6_K
```
*Best for: Fast bug fixes, refactoring specific functions, line-by-line help.*

### 3. Complex Debugging (The "Architect" Loop)
```sh
aider --model ollama/deepseek-r1:32b-q6_K
```
*Best for: When you have a logic bug that standard models can't solve. Uses Chain-of-Thought.*

## ⚙️ Configuration
The installer automatically configures:
- **~/.config/opencode/opencode.json**: Points to your local 32B models.
- **~/.aider.conf.yml**: Optimized for local Ollama endpoints.
- **128K Context Window**: Pre-configured in the Modelfiles.

---
**Maintained by IFAKA** | *Part of the 2026 Local LLM Initiative*
