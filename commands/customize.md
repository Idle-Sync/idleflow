---
description: Customize idleflow for this project: numbers (diff limit, implementers, retries, debate rounds, size budgets), steps on or off (debate, stack and library research, tooling, doc-keeper), the model of any agent, extra instructions for an agent, or a full replacement of an agent's prompt. Saved in .idleflow/ and .claude/agents/, committed for the team, kept mergeable with plugin updates. Each change can be reported to Idle-Sync/idleflow (asked once, remembered) so idleflow learns what projects change. Use when asked to "customize idleflow", "change the diff limit", "turn off the debate", "use opus for the planner", "change how the reviewer works", or to restore a default. Usage: /idleflow:customize [what to change]
argument-hint: [what to change]
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

How you talk to the human (plain language, `language:` and `tone:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You change this project's idleflow settings through `run.sh`, which validates every value; you never write `.idleflow/idleflow.conf` by hand.

```
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

Change: $ARGUMENTS

## 1. Where things stand

`bash "$RUN" migrate` (stop on a non-zero exit, showing its message). If `.idleflow/runs/active/` exists, say a run is in progress and stop: a run must not change settings under itself. Then `bash "$RUN" custom list` and `bash "$RUN" conf`. Show the human the current customizations, or `No customizations yet.`

## 2. What to change

When `$ARGUMENTS` (or a suggestion that brought you here) already names the change, take it. Otherwise ask with AskUserQuestion: **A number** / **A step on or off** / **An agent** (model, extra instructions, full replacement) / **Back to a default**, then the specifics in a second call:

- **Numbers.** `DIFF_LIMIT`, `DIFF_SLACK`, `MAX_IMPLEMENTERS` (1–8), `SIZE_M_IMPLEMENTERS` (1–8), `DEBATE_ROUNDS` (1–2), `MAX_RETRIES` (0–3), `SIZE_S_MAX`, `SIZE_M_MAX`, `SIZE_S_OVERRUN`, `LARGE_REPO_LOC`, and `DIFF_EXCLUDE_ADD` (space-separated `**/`-prefixed globs added to the diff gate's excludes). Show the current value and what it controls (the comment above it in `${CLAUDE_PLUGIN_ROOT}/config/idleflow.conf`).
- **Steps.** `STEP_DEBATE`, `STEP_STACK`, `STEP_LIBRARIES`, `STEP_TOOLING`, `STEP_DOC_KEEPER`, `STEP_MUTATION` (implementers break their own change on purpose to prove the tests catch it), `STEP_DESIGN` (the designer and design reviewer for work a person sees): `auto` (the run's own condition), `on`, `off`.
- **An agent.** Pick it from `ls "${CLAUDE_PLUGIN_ROOT}/agents"`. Then one of:
  - **Model** (`MODEL_<AGENT>`, e.g. `MODEL_REVIEW_CORRECT`): `haiku`, `sonnet`, `opus`, `fable`.
  - **Extra instructions (Recommended)**: written to `.idleflow/agents/<agent>.md` and added to the built-in prompt every time it runs; plugin updates keep reaching the agent. Write what the human wants as plain rules, no meta commentary.
  - **Full replacement**: `bash "$RUN" custom replace <agent>` copies the built-in prompt to `.claude/agents/idleflow-<agent>.md` and keeps a base copy so `/idleflow:doctor` can merge later plugin updates in (`run.sh custom merge <agent>`). Apply the human's edits to that file. Its output contract (output file, reply line, report fields) stays the built-in one: the orchestrator tells the agent so on every spawn. Tell the human the replacement takes effect after a Claude Code restart.
- **Language and tone.** Edit `language:` and `tone:` under "Talking to the human" in `.idleflow/conventions.md` (`auto` or a language name; `plain`, `friendly` or `terse`). These change only how idleflow talks to people, so they are committed with the change but not reported.
- **Back to a default.** `bash "$RUN" custom unset <KEY>`, or `bash "$RUN" custom restore <agent>` for everything about one agent.

Pushback before writing, once, with the evidence: a cheaper model on `review-correct` or `review-conform` weakens the quality gate the whole workflow stands on; `MAX_RETRIES=0` stops a run at the first rejection; `STEP_DEBATE=off` on a repo whose lessons show plan mistakes; a `DIFF_LIMIT` far above what the gate files in `.idleflow/runs/*/tasks/*/gate.json` show this repo needs. Then do what the human decides.

Write numbers, steps and models with `bash "$RUN" custom set <KEY> <value>`; a refusal means the value is out of range, so show it and ask again.

## 3. Commit

Stage only what changed (`.idleflow/idleflow.conf`, `.idleflow/agents/`, `.claude/agents/idleflow-*.md`) and commit `chore: customize idleflow: <one-line summary>`. Follow `CLAUDE.md` for the `Co-Authored-By` trailer. The team gets the change on their next pull.

## 4. Report it to idleflow

`bash "$RUN" custom report` prints this person's answer. It lives in this clone's git config, never in a committed file, so one teammate's "always" never posts from another teammate's account.

- `never`: skip this step.
- `ask`: ask with AskUserQuestion: **Report it** (a public comment on Idle-Sync/idleflow from your GitHub account, so idleflow learns what projects change) / **Always report** / **Never report** / **Not this time**. On always or never, `bash "$RUN" custom report always|never` (nothing to commit).
- `always`: report without asking, except for extra instructions and a replaced prompt, whose text may describe the project: show exactly what will be posted and ask **Post it** / **Not this time** every time.

To report: ask for a one-line reason (optional; "skip" is fine). `gh auth status` must pass; otherwise print the comment below for the human to paste and continue. Each setting has one issue, titled `customization: <KEY>` for numbers and steps, `customization: model <agent>`, `customization: instructions <agent>`, `customization: prompt <agent>`. Find it: `gh issue list --repo Idle-Sync/idleflow --state all --search "in:title \"<title>\"" --json number,title` and take the exact title match. Comment on it with `gh issue comment`; when none exists, `gh issue create --repo Idle-Sync/idleflow --title "<title>" --body-file <file>` with the comment as the body, then `gh issue edit <number> --add-label customization` (ignore the error if the label does not exist). The comment:

```
idleflow <version>: <KEY>: <old or default> -> <new>
reason: <the reason, or "not given">
```

For extra instructions, add the instruction text in a fenced block. For a replaced prompt, add `diff -u .idleflow/agents/<agent>.base.md .claude/agents/idleflow-<agent>.md` in a fenced `diff` block. Never include the repo name, paths outside these files, code, plans or anything from `prd.md`.

## 5. Reply

One line per change: `<KEY or agent>: <old> -> <new> (committed <sha>; reported <url> | not reported)`, plus `restart Claude Code to use it` for a replaced agent.
