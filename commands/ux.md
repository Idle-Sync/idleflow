---
description: "Use the running app the way its end users would and report every place they get stuck, confused or misled, each with a screenshot, the step that caused it and the change that removes it. Walks the journeys you name, or the ones end users depend on most, at phone and desktop widths. On your yes, fixes the findings through an idleflow run and walks the journeys again. Usage: /idleflow:ux [journeys to walk]"
argument-hint: "[journeys to walk]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

How you talk to the human (plain language, `language:`, `tone:` and `explain:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You run the review and report; fixes are made by an idleflow run this command starts, never by you directly. How the review walks the app is in `${CLAUDE_PLUGIN_ROOT}/procedures/ux-review.md`.

```bash
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

Agents are exposed as `idleflow:<name>`; spawn each as `commands/feature.md` **Spawning an agent** says (`bash "$RUN" agent <name>` first).

## 1. Is there an app to use

`bash "$RUN" ui`. On `no`, tell the human the repo has no screens an end user uses and stop. When `.idleflow/conventions.md` is missing, run R1 of `${CLAUDE_PLUGIN_ROOT}/procedures/repo-setup.md` first, then commit what it wrote (`chore: idleflow conventions`).

## 2. The review

`bash "$RUN" new --audit ux` (an audit run builds nothing). `new` parks a run left active and says so: repeat that line, and that `/idleflow:feature resume <id>` brings it back. It refuses, changing nothing, while one of that run's jobs or previews still runs: show its message and stop.

1. **Where the app is served.** `bash "$RUN" commands`. When `preview` is listed and unapproved, ask as `commands/feature.md` **Repo commands** says. With an approved preview, `bash "$RUN" preview main start` and keep the address it prints. Without one, ask once: **Give the address of the app running on this machine** (the human starts the app) / **Stop** (nothing can be walked without the app). Take only an `http` or `https` address on `localhost`, `127.0.0.1` or `[::1]`; ask again for any other, and never pass one on.
2. **Spawn `idleflow:review-ux`** in audit mode with: the repo root, the address, the journeys the human named in the arguments (or `none`), `prd.md` when it exists, the design-system path when it exists (`bash "$RUN" path design-system`), `${CLAUDE_PLUGIN_ROOT}/procedures/ux-review.md`, the output path `.idleflow/runs/active/review/audit-ux.md` and the screenshots folder `.idleflow/runs/active/review/audit-ux/`.
3. `bash "$RUN" preview main stop` when step 1 started it.

## 3. The report

Read `audit-ux.md`. Tell the human which journeys were walked, which could not be and why, and each finding in one line: the journey and step, what the end user meets, its severity. Give the report's path and the screenshots folder as they will be once the run finishes: `.idleflow/runs/<the id step 2's new printed>/review/audit-ux.md` and `.../review/audit-ux/`.

Ask: **Fix them** / **Fix the blocking and major ones** / **Report only**. On report only, `bash "$RUN" finish done` and stop.

## 4. The fix

1. Write `.idleflow/runs/active/review/ux-fix-issue.md`, the issue for the fix run, titled `UX: <the journeys>`. It lists each finding the human chose, with its journey, step, what the end user meets, its cause and its fix, plus its screenshot's path as it will be once the run finishes (under `.idleflow/runs/<the id step 2's new printed>/review/audit-ux/`). Its acceptance: each listed journey can be completed at both widths without the listed finding, and the fix adds no new place an end user gets stuck on the same journeys.
2. `bash "$RUN" finish done`. The fix issue is now `.idleflow/runs/<the id step 2's new printed>/review/ux-fix-issue.md`, and the review is beside it.
3. Read `${CLAUDE_PLUGIN_ROOT}/commands/feature.md` and follow it with the fix issue's path as the issue. Its UI tasks get the UX reviewer as that file says. Come back here when it ends with the tasks merged; when it ends otherwise, report that and stop.

## 5. Walked again

After the merges, with no run active: `bash "$RUN" new --audit ux-check`, then steps 2.1 to 2.3 with the fixed journeys as the journeys and the output path `.idleflow/runs/active/review/check-ux.md` (screenshots in `.idleflow/runs/active/review/check-ux/`). Tell the human which findings are gone, any that remain, and any new one, each with its screenshot's path under `.idleflow/runs/<the id this new printed>/review/check-ux/`, where `finish` puts it. A new finding is never left unreported: offer to fix it as in step 3. Then `bash "$RUN" finish done`.
