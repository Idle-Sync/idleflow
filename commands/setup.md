---
description: Set idleflow up in a project that already has code, before the first /idleflow:feature run. Maps the code, asks the repo's rules once (readability mode, ignore file, project docs, lessons location), records the stack the project already uses, offers tooling, writes the project docs and commits them for the team. On a repo already set up (by /idleflow:init or an earlier setup) it fills only what is missing, or runs /idleflow:doctor when nothing is. Optional: /idleflow:feature asks the same questions on its first run. Use when moving an existing project to idleflow, or when asked to "set up idleflow here", "onboard this repo". Not the plugin install; that is setup.md in the plugin. Usage: /idleflow:setup [one line on what the project is]
argument-hint: [one line on what the project is]
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

How you talk to the human (plain language, `language:` and `tone:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You set the repo up; you do not write application code, and you do not install anything into the repo. Every answer you collect here is one question the first feature run does not have to ask.

Plugin root: `${CLAUDE_PLUGIN_ROOT}`. Agents are exposed as `idleflow:<name>`. Templates: `${CLAUDE_PLUGIN_ROOT}/templates/`. Shared setup steps R1–R6: `${CLAUDE_PLUGIN_ROOT}/procedures/repo-setup.md` (read it now).

```
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

Project: $ARGUMENTS

Record paths: where this file names `progress.md`, `index.md`, `docs/sessions/`, the lessons file or the time log, use the path `bash "$RUN" path progress|index|sessions|lessons|time-log` prints; a repo can keep its records elsewhere (conventions "Records"), and agents get the resolved paths in their prompts.

Pushback applies throughout, as in `procedures/repo-setup.md`.

## 0. Which case is this?

1. `git rev-parse --show-toplevel` must succeed; otherwise say `Not a git repo. Run git init first, or /idleflow:init for a new project.` and stop.
2. `bash "$RUN" migrate` (stop on a non-zero exit, showing its message) and `bash "$RUN" update-check` (repeat its line once).
3. If `.idleflow/runs/active/` exists, say a run is in progress and stop: setup changes the files that run reads.
4. `bash "$RUN" loc`. At 0 the folder has no code: say `No code here yet: /idleflow:init is for new projects.` and stop.
5. `bash "$RUN" doctor`. If no line is `fail` and the `conventions`, `lessons` and `docs` lines are `ok`, the repo is already set up: say `idleflow is already set up here.`, then read `${CLAUDE_PLUGIN_ROOT}/commands/doctor.md` and follow it. Otherwise continue; each step below runs only for what is still unanswered or missing, so a repo `/idleflow:init` set up gets only its gaps filled.

`ID=$(bash "$RUN" new setup)`. `LESSONS=$(bash "$RUN" path lessons)`. Tell the human: `Setting up idleflow in <repo name>. Mapping the code first.`

## 1. Map the code (Sonnet)

Write `.idleflow/runs/active/issue.md`: `Set this repository up for idleflow. Map it for the project docs: what it does, its entry points, how to install, test and run it, its conventions.` plus `$ARGUMENTS` when given. Spawn `idleflow:explorer` with that issue path, the `$LESSONS` path, the output path `.idleflow/runs/active/context.md` and the template path. Wait.

## 2. Repo rules

Run **R1** (readability mode, ignore file) for whatever is unanswered.

**Project docs**, when `docs:` is `unset` in `.idleflow/conventions.md` (ask; do not infer it the way R2 does for a feature run): **Yes (Recommended for teams)** — `prd.md`, `progress.md`, `index.md`, a `CLAUDE.md` block and `docs/` keep every session and every teammate on the same page, and the doc-keeper keeps them true; cons: more files to keep current. **No** — idleflow runs without project docs; cons: no shared progress or handoff. Write the answer, then run **R2** (it asks `docs_in_git` and `lessons_in` when they apply). Ensure `$LESSONS` exists after R2 (`bash "$RUN" path lessons` again: the answer may have moved it), copying `templates/lessons.md` if not.

## 3. The stack it already has

When "Stack decisions" in conventions is empty: spawn `idleflow:stack-advisor` in mode `scan` as in **R3** step 1, with `greenfield` false and `context.md` as the project description. Read `stack-scan.md` and write what the project already uses under "Stack decisions", one line each: `- [in use] <tool>: <what for> (<file that shows it>)` (language and version pin, package manager and lockfile, test runner, formatter and linter, CI, containers). These record the project as it is; they are not proposals.

If the scan reports gaps, ask once: **Research the gaps now** (runs R3 steps 2–6: research, proposals, the human accepts or declines each) / **Not now** (list the gaps in `progress.md` "Next" when docs are on). An existing project never gets a new stack proposed in place of one it has; a proposal fills a gap or replaces a tool only when the scan cites a problem with it.

Skip **R4**: there is no feature yet to need a library.

## 4. Tooling

Run **R5** when nothing is under "Tooling" yet (setup counts as size L for its condition).

## 5. Project docs (when `docs: yes`)

1. **R2** steps 1 and 2 created what was missing. Fill `CLAUDE.md` "Commands" from `context.md` §5 (install, test, run). Leave `co_author_claude:` and `releases:` as they are; when they are still placeholders, ask both in one AskUserQuestion call with the options `/idleflow:init` step 3 gives them.
2. `index.md`, when it is still the template: write it from the repo as it is (`git ls-files` top-level directories, the entry points in `context.md` §2, the commands), under 80 lines, keeping "Start here" and "Run it". Nothing a path check would not confirm.
3. `prd.md`, when it is still the template: ask **Write it now** (three questions in one AskUserQuestion call: what the project is for and who uses it, what must be true by the next milestone, what is out of scope; then spawn `idleflow:planner` in PRD mode with `.idleflow/runs/active/brainstorm.md` holding the answers verbatim plus `context.md` §1–§2 as a summary, `.idleflow/conventions.md` and `templates/prd.md`; there is no market research for an existing project) / **Later** (the first feature run's planner reads it from the issue). The planner also writes the milestones into `progress.md`. Never write a PRD from the code alone: the code says what exists, not where the project is going.
4. `progress.md`: first "Log" entry under `<!-- progress start -->`: `## <date> — idleflow set up (run <ID>)`, three to five bullets: readability mode, docs and lessons location, stack recorded (N tools), tooling (N installed), next.

## 6. Commit and finish

**Team.** Unless `.claude/settings.json` already names `idleflow@idlesync`, ask once: **Recommend idleflow to everyone who opens this repo (Recommended when others work here)** — `bash "$RUN" team-install` adds it to the committed `.claude/settings.json` (Claude Code then loads it for a teammate once they trust the folder) and adds an install note to `CLAUDE.md` for sessions that have not loaded it; cons: it changes the team's Claude Code settings file, so say that in review. **Just me for now** — nothing changes; `/idleflow:doctor` suggests it once a second person commits. On yes, commit those two files alone: `chore: recommend idleflow to the team`.

Run **R6** (snapshot): it commits `.idleflow/`, `CLAUDE.md`, the project docs and `docs/`, so every teammate who pulls gets the same setup.

**Plugin gaps** as in `commands/feature.md` step 9, then `bash "$RUN" finish done`.

Final message, nothing more: one line each for readability mode, docs (and where lessons live), stack recorded, tooling installed (and the restart it needs, if any); the commit; `Next: /idleflow:feature "<the first item from prd.md or progress.md Next, or: describe the change>"`. Then ask: **Start a feature now** / **End the session** (read `${CLAUDE_PLUGIN_ROOT}/commands/endsession.md` and follow it; this answer is its yes) / **Stop here**.

## Rules you never break

- Never write application code, change a build file or install a dependency into the repo. Gaps become proposals; accepted proposals become tasks in a feature run.
- Never overwrite a human's content in `CLAUDE.md`, `README.md`, `prd.md` or `progress.md`: fill templates and add entries, nothing else.
- Never ask a question whose answer is already in `.idleflow/conventions.md` or `CLAUDE.md`.
- No meta commentary in any file or commit.
