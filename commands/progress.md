---
description: Where the project stands, for one person or a whole team. Shows each prd.md milestone with its Must-do boxes ticked and open, what landed recently and who landed it, the run in progress, what's next from the latest handoff, and what is waiting on a human. Read-only. Use when asked "where are we", "project status", "what's left for the milestone", "what did the team do this week", "progress". Usage: /idleflow:progress [milestone, person, or number of days]
argument-hint: [milestone, person, or number of days]
allowed-tools: Bash, Read, Grep, Glob
---

You report; you change nothing. Everything you state comes from a file or a git command you ran this turn; when a source is missing, say which and skip that part.

```
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

Focus: $ARGUMENTS (a milestone like `M2`, a person's name, or a number of days; default 14 days, everything)

## Gather

The committed files are the team's shared record; `.idleflow/runs/` holds only this clone's runs.

- **Milestones.** `progress.md` "Milestones": each `### M<n>` heading and its `- [x]` / `- [ ]` boxes. When milestones are still in `prd.md` (the layout before milestones moved), say so, point to `/idleflow:doctor` to move them, and report from `prd.md` as untracked.
- **Landed work, the whole team's.** `git log --since="<days> days ago" --format='%h|%an|%ad|%s' --date=short` on the current branch, and among them the `idleflow: merge <task> (<run id>)` commits (`--grep '^idleflow: merge'`), which show each run and who merged it. The newest entries of `progress.md`.
- **In progress.** `.idleflow/runs/active/run.json` in this clone (id, `by`, status, tasks not yet approved). Teammates' active runs are not visible from here; say so once when the log shows more than one author.
- **Next.** The "Next" list of the newest note in `docs/sessions/` by name, and the latest "next" bullet in `progress.md`.
- **Waiting on a human.** Runs in `.idleflow/runs/log.jsonl` with status `needs-human` newer than the last `done`; the `fail`, `warn` and `suggest` lines of `bash "$RUN" doctor` (count them, name the `fail` ones); `bash "$RUN" behind` when it prints a number.

## Report

In this order, short, paths and names rather than prose:

1. **Milestones**: one line each, `M<n> <title>: <ticked>/<total> (<percent>%)`; under the first milestone that is not complete, its open boxes, one line each.
2. **Landed** in the window: one line per run or commit group, `<date> <who>: <what> (<run id or sha>)`; at most ten, newest first.
3. **In progress**: the active run in this clone, or `none here`.
4. **Next**: the first three items of the newest handoff, in its order.
5. **Waiting on a human**: needs-human runs with their reason, doctor problems, commits to pull.

When the focus names a milestone or a person, filter every section to it. End with one line: `Milestone <n>: <ticked>/<total>; <N> people active in <days> days.`
