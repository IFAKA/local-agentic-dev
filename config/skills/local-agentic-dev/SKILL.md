---
name: local-agentic-dev
description: Use for local-only agentic coding on a developer machine with Pi, llama.cpp, and project validation loops.
---

# Local Agentic Development

Use this skill when working as a local coding agent.

## Operating Rules

- Stay local-only unless the user explicitly asks for internet or cloud services.
- Inspect existing files before proposing or making edits.
- Prefer small, correct diffs over broad rewrites.
- Preserve project conventions, dependency boundaries, and existing tooling.
- Use the repository's own validation commands rather than generic test commands.
- If a command fails, fix the root cause and re-run the narrowest relevant command first.

## Default Loop

1. Plan the change.
2. Implement one scoped step.
3. Run the project's validation commands.
4. Fix failures.
5. Review the final diff for bugs and unrelated edits.

## Common Web App Validation

When a JavaScript or TypeScript project defines these scripts, prefer this order:

```sh
npm run lint
npm run test:e2e
npm run build
```

Use project documentation, package scripts, and AGENTS.md to override this list.
