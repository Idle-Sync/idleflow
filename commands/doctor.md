---
description: Check this repo's idleflow setup and whether a newer idleflow is out. Reports every check (layout, conventions, lessons, what the team shares, ignore rules, leftover runs and worktrees, project docs, customizations), then offers the safe fixes. Use when idleflow behaves oddly, after updating the plugin, when a teammate joins, or when asked "is idleflow set up right", "check idleflow", "idleflow doctor". Usage: /idleflow:doctor
argument-hint: ""
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

How you talk to the human (plain language, `language:` and `tone:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You check and report first; you change nothing until the human picks a fix.

```
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

1. `bash "$RUN" doctor`. Each line is `ok|warn|fail|suggest <check>: <detail>`, with `| fix: <how>` when there is a fix. Outside a git repo it fails; say `Not a git repo: idleflow needs one (git init).` and stop.
2. Show the human the lines as a short checklist, `fail` first, then `warn`, then `suggest`, then a one-line count of `ok`. Do not paraphrase the details.
3. If nothing is `warn`, `fail` or `suggest`, reply `idleflow: all <N> checks pass` and stop.
4. Ask once with AskUserQuestion, `multiSelect: true`, one option per `warn` or `fail` line that has a fix (label = the check name; description = the detail and the fix). Leave out an `update` fix while `.idleflow/runs/active/` exists: a plugin update mid-run mixes versions. Selected means fix it.
5. Apply the selected fixes in this order, and show each command's output:
   - `run.sh <args>` → `bash "$RUN" <args>`. `migrate` runs before every other fix.
   - `/idleflow:<command>` → read `${CLAUDE_PLUGIN_ROOT}/commands/<command>.md` and follow it.
   - an update → run the quoted commands exactly, then tell the human the new version takes effect after a Claude Code restart, not before.
   - the `milestones` fix → `procedures/repo-setup.md` R2 step 5 (it shows the diff and asks before committing).
   - anything else (merge two lessons files, remove an ignore rule) → do it with the smallest edit, show the diff, and commit it alone: `chore: <what was fixed>`.
6. `suggest fit <key>` lines are settings that would fit this repo's own rules better, with the evidence: offer them together (multi-select) and apply the chosen ones by following `${CLAUDE_PLUGIN_ROOT}/commands/setup.md` step 2b for those keys only; a declined one gets `- declined: <key> -> <value> (doctor, <date>)` in `.idleflow/suggestions.md`. Other `suggest` lines are the retro's customization suggestions that are still open. Offer each once, after the fixes, with its evidence: **Apply it** (read `${CLAUDE_PLUGIN_ROOT}/commands/customize.md` and follow it with that change) / **Not now** / **Never suggest this** (append `- declined: <KEY> -> <value> (doctor, <date>)` to `.idleflow/suggestions.md` and commit that file alone: `chore: decline idleflow suggestion <KEY>`).
7. `bash "$RUN" doctor` again and reply with only the lines that are still `warn` or `fail`, or `idleflow: all <N> checks pass`.

Never fix something the human did not select, and never delete a run directory, a worktree with uncommitted work, or a lessons line.
