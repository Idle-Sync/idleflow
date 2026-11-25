---
description: "Find the bugs that appear only over time: behaviour that depends on time passing, on state building up, or on a step stopping partway. Maps every lifecycle in the code, plays each out over long simulated use with a controlled clock in the project's own tests, and probes time and order boundaries, interrupted and repeated steps and outside services that fail. Each bug comes back as a scenario with a test that fails on it; on your yes, they are fixed through an idleflow run. Usage: /idleflow:lifecycle [the part of the code to hunt]"
argument-hint: "[the part of the code to hunt]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

How you talk to the human (plain language, `language:`, `tone:` and `explain:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You run the hunt and report; `idleflow:lifecycle-hunter` hunts, in a worktree that is never merged, and fixes are made by an idleflow run this command starts. Spawn agents as `commands/feature.md` **Spawning an agent** says (`bash "$RUN" agent <name>` first).

```bash
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

## 1. The hunt's worktree

When `.idleflow/conventions.md` is missing, run R1 of `${CLAUDE_PLUGIN_ROOT}/procedures/repo-setup.md` first, then commit what it wrote (`chore: idleflow conventions`).

`bash "$RUN" new --audit lifecycle` and keep the id it prints. It parks a run left active and says so: repeat that line, and that `/idleflow:feature resume <id>` brings it back. It refuses, changing nothing, while one of that run's jobs or previews still runs: show its message and stop.

`bash "$RUN" commands`; for each `unapproved` line among `worktree_setup`, `gate` and `services`, ask as `commands/feature.md` **Repo commands** says. Then `WT=$(bash "$RUN" wt add HUNT)`. When it exits non-zero, it printed no path: show the end of its message, run `bash "$RUN" wt rm HUNT`, `git branch -D idleflow/<the run id>/HUNT` (when the branch exists) and `bash "$RUN" finish needs-human`, and stop. Then `bash "$RUN" own HUNT '["**"]'`: the hunt may write probes anywhere in its own worktree, which nothing merges. When the repo has an approved `services:` check, run it as `commands/feature.md` step 0 **The services the tests need** says before the hunt.

## 2. The hunt

Spawn `idleflow:lifecycle-hunter` with: the worktree path `$WT`, `Run commands with: bash "<absolute path of run.sh>" exec HUNT -- <command>`, the repo's test command (under `gate_runs: once` in conventions, `Repo gate: <gate_quick from conventions>` when it is set; otherwise `Repo gate: <bash "$RUN" get gate>`, or `Repo gate: none` when that is empty), the scope (the human's argument, or `all`), `${CLAUDE_PLUGIN_ROOT}/procedures/lifecycle-hunt.md`, and two absolute paths in the main checkout: the output path `<repo root>/.idleflow/runs/active/lifecycle/report.md` and `Failing tests: <repo root>/.idleflow/runs/active/lifecycle/tests/`.

When it has replied, before anything is removed: the report must exist (`test -s` on its path), and, when its reply counts bugs, the failing-tests folder too. On a miss, re-spawn it once with the same prompt; on a second miss, tell the human the hunt wrote no report. Then `bash "$RUN" wt rm HUNT` and `git branch -D idleflow/<the run id>/HUNT` (the hunt never commits; its probes are not kept). With no report, `bash "$RUN" finish needs-human` and stop.

## 3. The report

Read `report.md`. Tell the human how many lifecycles were mapped and hunted, which could not be hunted and what was missing, and each bug in one line: the lifecycle, what goes wrong and after which step, its severity. Give the report's path, and the failing tests' folder, as they will be once the run finishes: `.idleflow/runs/<the run id>/lifecycle/`.

With no bug, `bash "$RUN" finish done` and stop: there is nothing to choose. Otherwise ask, offering only the choices that pick at least one bug: **Fix them all** / **Fix the blocking and major ones** / **Report only**. On report only, `bash "$RUN" finish done` and stop.

## 4. The fix

1. Write `.idleflow/runs/active/lifecycle/fix-issue.md`, titled `Lifecycle bugs: <the lifecycles>`. For each bug the human chose: its scenario, the rule that fails, the step and the cause, the full text of its failing test with the path it belongs at in the repo, and its fix. The acceptance: each of those tests is added to the repo at that path and passes, the repo's other tests still pass, and the cause is fixed where the report names it, not where the symptom shows.
2. `bash "$RUN" finish done`. The fix issue is now `.idleflow/runs/<the run id>/lifecycle/fix-issue.md`.
3. Read `${CLAUDE_PLUGIN_ROOT}/commands/fix.md` and follow it with that path as the issue. Its explorer, plan, reviews and merges apply as for any fix.

## Rules

- Nothing from the hunt's worktree reaches the repo except through the fix run.
- Never present a suspicion as a bug: a bug in the report has a test that fails on it.
