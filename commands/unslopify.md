---
description: "Find what makes a project's UI read as AI-generated, and fix it at the level you choose. Scans the code and the rendered pages against a cited catalogue of patterns, weighs each against the project's design system so a chosen look is never treated as a default, scores pages on combinations of patterns rather than single hits, and reports. On your choice of polish, restyle or redesign it fixes through an idleflow run with the project's own tokens, then checks the fixed pages again so one generic look is not traded for another. Usage: /idleflow:unslopify [pages or screens to audit]"
argument-hint: "[pages or screens to audit]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

How you talk to the human (plain language, `language:`, `tone:` and `explain:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You audit and report; fixes are made by an idleflow run that this command starts, never by you directly. The catalogue, the chosen-or-default rule, the scoring and the fix levels are in `${CLAUDE_PLUGIN_ROOT}/procedures/slop.md`; read it now.

```bash
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
SCAN="${CLAUDE_PLUGIN_ROOT}/scripts/slop-scan.sh"
```

Agents are exposed as `idleflow:<name>`; spawn each as `commands/feature.md` **Spawning an agent** says (`bash "$RUN" agent <name>` first).

## 1. Is there a UI

`bash "$RUN" ui`. On `no`, tell the human the repo has no screens this command can audit and stop. When `.idleflow/conventions.md` is missing, run R1 of `${CLAUDE_PLUGIN_ROOT}/procedures/repo-setup.md` first, then commit what it wrote (`chore: idleflow conventions`).

## 2. The audit run

`bash "$RUN" new --audit unslopify` (an audit run builds nothing). `new` parks a run left active and says so: repeat that line, and that `/idleflow:feature resume <id>` brings it back. It refuses, changing nothing, while one of that run's jobs or previews still runs: show its message and stop. Its folder is `.idleflow/runs/active/`; write everything below into `.idleflow/runs/active/slop/`.

1. **Static tier.** `bash "$SCAN" --repo "$(git rev-parse --show-toplevel)" > .idleflow/runs/active/slop/static.tsv`.
2. **Where the app is served.** `bash "$RUN" commands`. When `preview` is listed and unapproved, ask as `commands/feature.md` **Repo commands** says. With an approved preview, `bash "$RUN" preview main start` and keep the address it prints. Without one, ask once: **Give the address of the app running on this machine** (it must be a localhost address; the human starts the app) / **Audit without rendering** (the rendered patterns are reported as unverified).
3. **Spawn `idleflow:slop-auditor`** in Audit mode with: the repo root, `${CLAUDE_PLUGIN_ROOT}/procedures/slop.md`, `${CLAUDE_PLUGIN_ROOT}/docs/research/human-made.md`, the path of `static.tsv`, `${CLAUDE_PLUGIN_ROOT}/scripts/slop-page.js`, the design-system path (`bash "$RUN" path design-system`, or `none` when no file is there), `.idleflow/slop-waivers.md` (or `none`), the address (or `Pages: none (<reason>)`), the pages the human named in the arguments (or `none`), the output path `.idleflow/runs/active/slop/audit.md` and `Talking rules: ${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`.

## 3. The report and the human's choices

Read `audit.md`. Tell the human how the pages feel (made by people, mixed or generated, and how sure the auditor is: the line between them is a judgement, not a rule), the repo's score and the looks it reads as, each page's verdict and score in one line, the notes (palette patterns, which are not scored) in one line, what was left as chosen, and what is unverified; when the report's `catalogue:` line says `due a refresh`, say that the catalogue is older than six months, so newer patterns may be missing. Give the report's path.

1. **Ask** each item under "Ask" (four per AskUserQuestion call): **Chosen on purpose** / **A default**. Append each chosen one to `.idleflow/slop-waivers.md` (create it with the heading `# Looks this project chose`): `- <pattern id> at <where>: <the human's reason, or "chosen"> (<date>)`. A default stays a default. When any answer changed a page's score, spawn the auditor again in Audit mode with the same inputs, so the report and its fixes match the answers. When the same pattern has been waived three times or more, suggest writing the choice into the design-system file, where every run reads it.
2. `bash "$RUN" preview main stop` when step 2 started it, now that no re-audit is left. When the report has notes, ask once whether to include them in the fix (**Leave the notes**, recommended / **Fix the notes too**). **The level**: ask **Report only**, **Polish**, **Restyle** and **Redesign**, the auditor's recommendation first, each with what it would change from the report's "Fixes". On report only, commit the waivers file when it changed (`chore: record the looks this project chose`), `bash "$RUN" finish done`, and stop.
3. **Restyle** only: ask about each proposed token change (multiSelect, four per question). A token with `source: the human's choice` needs the value from the human: ask for it, or for a reference to take it from; without an answer, that token is left out. Only the approved changes go ahead.

## 4. The fix

1. Write `.idleflow/runs/active/slop/fix-issue.md`, the issue for the fix run:
   - the title `Unslopify: <level> on <the pages>`;
   - what to change: for polish, every fix under "polish", and the fixes under "notes" when the human chose to fix the notes; for restyle, those plus each approved token change with its value; for redesign, the screens under "redesign" and the line `directions: yes` on its own;
   - the rules from `procedures/slop.md` **Fixing**, copied in full;
   - the absolute path of the audit's `static.tsv`, the baseline the acceptance compares with;
   - the acceptance: every listed pattern is gone from its place; `bash "<absolute path of slop-scan.sh>"` run in the task's own worktree (through `run.sh exec`) prints, for the files the task changed, none of the patterns listed for them and no pattern and file the audit's `static.tsv` lacks (compared by pattern and file, since a fix moves line numbers); links, ids, test hooks, handlers and routes in the changed files are unchanged; every changed line of copy is listed before and after in the task's report.
2. Commit the waivers file when it changed (`chore: record the looks this project chose`). `bash "$RUN" finish done`. The audit run's folder is now `.idleflow/runs/<the id step 2's new printed>/`: the fix issue is `<that folder>/slop/fix-issue.md` and the baseline below is `<that folder>/slop/audit.md`.
3. Read `${CLAUDE_PLUGIN_ROOT}/commands/feature.md` and follow it with the fix issue's new path as the issue. Its human questions, gate, reviews and merges apply as for any run. Come back here when it ends with the tasks merged; when it ends otherwise, report that and stop.

## 5. Checked again

After the fix run's merges, with no run active:

1. `bash "$RUN" new --audit unslopify-check`. Scan again as step 2.1, serve as step 2.2, and spawn the auditor in Check mode with step 2.3's inputs plus `Baseline: <the audit report>` and the fixed pages; output `.idleflow/runs/active/slop/check.md`. Stop the preview once the auditor has replied.
2. Read `check.md`. On `verdict: pass`, tell the human the new verdict and score per page, what was removed (`cleared:`), what was left as chosen, and the report's "Ceiling" in its own words.
3. On `verdict: fail`, show the new patterns and where they are, and ask: **Fix them now** (go to step 4 with polish, the fixes for the new patterns only, and this check as the baseline) / **Keep the result as it is**. A new pattern is never left unreported.
4. `bash "$RUN" finish done`.

## Rules

- Never call the result designed or slop-free; report what changed, what was kept as chosen, and what needs a human's taste.
- Nothing in the repo changes outside the fix run, except `.idleflow/slop-waivers.md`, which this command writes only with the human's answers.
