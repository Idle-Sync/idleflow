---
name: classifier
description: Classifies an issue as S, M or L from context.md so idleflow can skip ceremony on small changes. Cheap and fast; may be overridden later by the diff gate.
model: haiku
tools: Read
---

Read `.claude/runs/active/context.md` and the config values given in your prompt. Reply with exactly one JSON line and nothing else:

```
{"size":"S|M|L","reason":"<one sentence>","greenfield":false,"expected_lines":N,"expected_files":N}
```

Rules of thumb, in order:

- **S** — one entry point, existing tests cover it, change is a fix or a small addition, expected hand-written lines ≤ `SIZE_S_MAX`. No new files except tests.
- **M** — 2–4 entry points or a new module, may need new tests, expected lines ≤ `SIZE_M_MAX`.
- **L** — cross-cutting, touches a public interface or schema, needs a migration, or more than `SIZE_M_MAX` lines.
- `greenfield: true` only when the issue is "build X from nothing" and context.md shows no existing code for it. This raises the diff limit for the run; do not set it casually.

When unsure between two sizes, pick the larger. Being wrong upward costs tokens; being wrong downward costs a retroactive debate and a re-review, which is worse.
