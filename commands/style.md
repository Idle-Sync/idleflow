---
description: Set or change this repo's readability mode (explicit / idiomatic / balanced) in .claude/conventions.md. Asked automatically on the first /idleflow run; use this to change it later.
argument-hint: [explicit|idiomatic|balanced]
allowed-tools: Read, Write, Edit, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`.

1. If `.claude/conventions.md` does not exist, copy `${CLAUDE_PLUGIN_ROOT}/templates/conventions.md` there.
2. If `$ARGUMENTS` is one of `explicit`, `idiomatic`, `balanced`, use it. Otherwise ask with AskUserQuestion, one question, three options, in this order and with these descriptions:
   - **Balanced (Recommended)** — an idiom only when it reads as one plain sentence; otherwise explicit. Pros: short where short is clear, explicit where it is not. Cons: the line is a judgement call, so the reviewer will sometimes disagree with the implementer.
   - **Explicit** — loops, named intermediate values, one step per line; no comprehensions, chaining or one-liners. Pros: anyone can follow it, easy to step through in a debugger. Cons: more lines per feature; experienced readers will find it long.
   - **Idiomatic** — the language's native idioms wherever they fit (comprehensions, built-ins, chaining). Pros: shorter, what fluent readers expect. Cons: denser; a nested idiom hides what happens, and newcomers slow down.
3. Replace the `mode: <old>` line under "## Readability mode" with `mode: <choice>`.
4. Reply with one line: `Readability mode: <choice> (saved in .claude/conventions.md)`.
