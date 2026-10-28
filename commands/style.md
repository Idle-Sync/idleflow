---
description: Set or change this repo's readability mode (repo / balanced / explicit / idiomatic) in .idleflow/conventions.md. Asked automatically on the first /idleflow run; use this to change it later.
argument-hint: [repo|balanced|explicit|idiomatic]
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`.

0. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" migrate` (moves files an older idleflow kept under `.claude/`; a no-op otherwise). If it exits non-zero, show its message and stop.
1. If `.idleflow/conventions.md` does not exist, copy `${CLAUDE_PLUGIN_ROOT}/templates/conventions.md` there.
2. If `$ARGUMENTS` is one of `repo`, `balanced`, `explicit`, `idiomatic`, use it. Otherwise ask with AskUserQuestion, one question. When the repo has code (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" loc` is above 0; outside a git repo it fails, which counts as no code), the first option is:
   - **Match this repo (Recommended)** — write code the way the surrounding code is already written: naming, comment style and density, guard shape, call style and test structure copied from the files next to the change. Pros: changes read like the rest of the codebase. Cons: carries the repo's habits forward, the bad ones too. Its `preview` shows 8–15 lines quoted exactly from one representative source file (the largest non-test, non-generated file of the main language), its `path:line` on the first line.

   Then these three, in this order; on a repo with no code yet Balanced is first and marked Recommended:
   - **Balanced** — an idiom only when it reads as one plain sentence; otherwise explicit. Pros: short where short is clear, explicit where it is not. Cons: the line is a judgement call, so the reviewer will sometimes disagree with the implementer.
   - **Explicit** — loops, named intermediate values, one step per line; no comprehensions, chaining or one-liners. Pros: anyone can follow it, easy to step through in a debugger. Cons: more lines per feature; experienced readers will find it long.
   - **Idiomatic** — the language's native idioms wherever they fit (comprehensions, built-ins, chaining). Pros: shorter, what fluent readers expect. Cons: denser; a nested idiom hides what happens, and newcomers slow down.
3. Replace the `mode: <old>` line under "## Readability mode" with `mode: <choice>`.
4. Reply with one line: `Readability mode: <choice> (saved in .idleflow/conventions.md)`.
