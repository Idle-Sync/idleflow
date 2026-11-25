---
description: "Save a blueprint of one reusable part of this project, a feature or mechanism worth having again later: what it does and for whom, its flows, rules, states over time, edge cases, what it keeps, the outside services it needs by role, the lessons learned building it, and plain-language test cases, with no code and no stack. Kept in your personal library for any project, and in the repo on your yes. Build from one later with /idleflow:feature <the blueprint's path>. Usage: /idleflow:blueprint <the part to save>"
argument-hint: "<the part to save>"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

How you talk to the human (plain language, `language:`, `tone:` and `explain:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You set up the blueprint and save it; `idleflow:blueprinter` writes it. Spawn it as `commands/feature.md` **Spawning an agent** says (`bash "$RUN" agent blueprinter` first).

```bash
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
LIBRARY="$(bash "$RUN" path blueprints)"     # the human's own library, outside every repo, in this OS's form
```

## 1. Which part

The argument names the part. Without one, ask the human which part of the project to save. Make its name a short file name: lowercase words joined by hyphens, from what the part does. When `$LIBRARY/<name>.md` already exists, show its first lines and ask: **Replace it** / **Save as a new name** (ask for the name) / **Stop**.

## 2. Write it

`mkdir -p "$LIBRARY"`. Spawn `idleflow:blueprinter` with: the repo root, the part as the human named it, `${CLAUDE_PLUGIN_ROOT}/templates/blueprint.md`, the output path `$LIBRARY/<name>.md`, the lessons file (`bash "$RUN" path lessons`) and `progress.md` (`bash "$RUN" path progress`) when they exist, and `Check with: bash "<absolute path of run.sh>" blueprint-check <the output path>`.

Then `bash "$RUN" blueprint-check "$LIBRARY/<name>.md"` yourself. Exit 2 means the blueprinter wrote no file: re-spawn it once with the same prompt, and when it still writes none, tell the human and stop. Exit 1: send its lines back to the blueprinter once to rewrite; lines still listed after that are shown to the human, who decides whether they stay.

## 3. Save it

Tell the human the blueprint's path, its counts from the reply, and its open questions. Ask: **Also keep a copy in this repo** (`docs/blueprints/<name>.md`, committed so the team has it) / **Library only**. For the copy: `mkdir -p docs/blueprints`, copy the file, stage it by name and commit `docs: blueprint of <the part>`.

Then say how to build from it later, in this project or another: `/idleflow:feature <the blueprint's path>`.
