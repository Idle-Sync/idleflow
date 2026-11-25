---
name: vocab
description: "Keep one term per concept in a repo's Markdown. Use when writing or editing Markdown in a repo that has a vocabulary file (vocabulary_file: in .idleflow/conventions.md, or vocabulary.md at the root), when run.sh vocab reports hits, or when asked to check, fix, regularise or backfill the docs' terms, or to add or ban a term. Usage: /idleflow:vocab [check | fix | backfill | add <term>] [files]"
argument-hint: "[check | fix | backfill | add <term>] [files]"
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, AskUserQuestion
---

# Vocabulary

One term per concept: agents and people find things by exact text, so when a concept has two names, a search for one name misses every place that uses the other. The repo's vocabulary file names, per concept, the term to use and the spellings never to write. These steps are the one way idleflow checks and fixes that, inside a run and outside one.

```
RUN="<plugin root>/scripts/run.sh"   # the plugin root is two folders above this skill's base directory; keep the quotes
VOCAB="$(bash "$RUN" path vocabulary)"
```

The argument picks the step: `check`, `fix`, `backfill` or `add <term>`, with files after it for `check` and `fix`. With no argument, `check` the Markdown files that `git status --porcelain` shows as changed or new and that still exist, or `backfill` when the human asked about the whole repo. How you talk to the human follows the plugin's `procedures/talking.md`.

## Check

`bash "$RUN" vocab <files>` (or `--all` for every tracked Markdown file). Exit 0: no hit. Exit 2: it could not check; show its message. Exit 1: each line is `<file>:<line>: <word> → <use>`; show them, then **Fix** when the human or the calling step asks.

## Fix

For each hit line, on that line of that file only:
1. Write the term to use in place of the word, keeping the sentence grammatical: its article, number and capitalisation follow the new term, and nothing else on the line changes.
2. When the line must quote the banned word (a rule that bans it, a quoted name the repo does not own), leave the word and end the line with `<!-- vocab: allow -->`.
3. Run the check again on the same files, and repeat until it exits 0.

A hit inside code is never reported, so code is never touched.

## Backfill

The whole-repo pass, for a repo whose docs predate its vocabulary file or a newly banned word.
1. **No vocabulary file yet** (`test -f "$VOCAB"` fails): propose one. Start from the plugin's `templates/vocabulary.md`; for this repo's own concepts, look in its Markdown for one concept written more than one way, and propose a row for each with the spelling used most as the term. Ask with AskUserQuestion, `multiSelect: true`, one option per proposed row, the term and the spellings it bans in the description; write the file with the chosen rows and commit it alone: `docs: add a vocabulary file`.
2. `bash "$RUN" vocab --all`. With no hit, say so and stop.
3. Show the hits grouped by the term to use, with the count per file, and ask once: **Fix them all** / **Choose which terms** (multiSelect, one option per term) / **Not now**.
4. Apply **Fix** to the chosen hits, then commit only the files it changed: `docs: one term per concept`.

## Add a term

1. Ask for what is missing of the row: the term to use, what it means here, the spellings never to write. Each banned spelling is written in backticks in the file, so the file never flags itself.
2. Show the row and add it to the table in `$VOCAB` on the human's yes; commit it alone: `docs: vocabulary: <term>`.
3. The older docs may now hold a newly banned spelling: run `bash "$RUN" vocab --all` and, when it has hits, offer **Backfill** for them.

## Rules

- Change only what a hit names; never reword a sentence beyond the term.
- Commit only the files the step changed. The message is the one the step names when `bash "<run.sh>" commit-style` prints `conventional`; when it prints `plain`, the same words as a plain sentence with no prefix.
- No meta commentary in any file or commit.
