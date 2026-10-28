---
description: End a working session with a handoff and an honest report. Writes a session note whose "Next" lists, in order, what the next session does first (unpushed commits, CI, deploy and release steps, restarts, open deviations, uncommitted work), summarises the whole session (runs and the work around them), updates progress.md, and commits the notes, then reports what happened, what broke (Claude's own mistakes first, with evidence), what went right and what waits on the human. Refuses while a run is active or worktrees exist. Use when the human says they are stopping ("done for today", "wrap up", "end the session", "that's it for now", "hand off"); when Claude starts it on its own, it asks the human first and runs only on a yes. Usage: /idleflow:endsession [anything the next session must know]
argument-hint: [anything the next session must know]
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
---

How you talk to the human (plain language, `language:` and `tone:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You write the handoff for the next session. You do not change code, start a run, push, tag or deploy; you record what is left so the next session can do it.

Plugin root: `${CLAUDE_PLUGIN_ROOT}`.

```
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

Record paths: where this file names `progress.md`, `index.md`, `docs/sessions/`, the lessons file or the time log, use the path `bash "$RUN" path progress|index|sessions|lessons|time-log` prints; a repo can keep its records elsewhere (conventions "Records"), and agents get the resolved paths in their prompts.

Notes from the human: $ARGUMENTS

## 0. Only with a yes

If the human did not type `/idleflow:endsession` in this turn (you are starting it because they said they are stopping), ask first with AskUserQuestion: **Write the handoff and commit it** / **Not now**. On "Not now", stop and write nothing.

## 1. Refuse while anything is still running

First `bash "$RUN" migrate` (moves files an older idleflow kept under `.claude/`); if it exits non-zero, show its message and stop.

Stop, write nothing, and say what is still running when any of these holds:

- `.idleflow/runs/active/` exists: print its run id and status (`bash "$RUN" get id`, `bash "$RUN" get status`) and every task whose status is not `approved`. A handoff is written only after the run reached `finish`.
- `bash "$RUN" wt list` prints anything: list the worktrees.
- An agent you spawned in this session has not replied yet.

## 2. Gather, read-only

- **Git.** Current branch. Unpushed commits: `git rev-list --count @{u}..HEAD`; with no upstream, say `no upstream for <branch>` and the commit count since the default branch. Uncommitted changes: `git status --porcelain` (the paths only; you do not commit them).
- **CI.** When the unpushed commits touch `.github/workflows/`, CI has not run on the new workflow yet. When the branch is pushed and `gh` works, the newest run: `gh run list --branch <branch> --limit 1`; a failed or pending run is a next step.
- **Runs this session.** Lines of `.idleflow/runs/log.jsonl` whose `finished` is later than the commit time of the newest note in `docs/sessions/` (by name) with `by: Claude Code session` (`git log -1 --format=%cI -- <note>`); with no such note, the runs finished today. For each: id, status, size, and from `.idleflow/runs/<id>/tasks/*/report.md` every `deviations:` and `blocked_on:` that is not `none`. A run that finished `needs-human` is a next step with its reason.
- **Releases.** When `CLAUDE.md` says `releases: github-tagged` and a run this session proposed a tag (or every box of a `progress.md` milestone is ticked and it has no tag yet: `git tag --list`), the next step is the two commands from `CLAUDE.md` "Releases" with the version filled in. Deploy steps named in `CLAUDE.md` or `progress.md` that have not run are next steps too.
- **Restarts.** Tooling installed this session (`tooling_installed` above 0 in a run's `run.json`, or an install you ran yourself) and plugin updates mean the next session starts with a Claude Code restart.
- **The rest of the session.** Work done outside runs in this conversation: prototypes, research, decisions and their reasons, human decisions taken mid-run. You were there; write what happened, not what was said.

## 3. Write

Read `docs:` in `.idleflow/conventions.md`. When it is `no` (or the file is missing), print the note from the shape below in your reply, write nothing, and stop: the repo keeps no session notes.

When `docs: yes`:

1. The note at `$(bash "$RUN" session-name)` (named by time and author, so teammates never pick the same name), from `docs/sessions/TEMPLATE.md`, `by: Claude Code session, <git user.name>`. "Done" covers the whole session: each run (id, title, what merged, with paths) and the work outside runs. "Next" is the handoff: a numbered list in the order the next session should do it, each item one line with the exact command where there is one. Uncommitted changes and unpushed commits come first, then CI, then restarts, then release and deploy steps, then `needs-human` runs and open deviations, then the first open box of the first unfinished milestone in `progress.md`. Add the human's notes from `$ARGUMENTS` where they belong. "Open questions" holds what the human still has to decide.
2. `progress.md`: one entry at the top, under `<!-- progress start -->`: `## <date> — session end`, at most four bullets: what landed this session, and the first two items of the handoff. Skip it when a run's retro already wrote an entry today and nothing landed since; the note alone carries the handoff then.
3. Stage only those two files and commit: `docs: session handoff`. Follow `CLAUDE.md` for the `Co-Authored-By` trailer. `git add` refuses an ignored path (a `docs/` kept local): skip it, never `git add -f`, and say the note stays local.

No meta commentary in the note or the commit: state what happened and what is next.

## 4. Report

Print the session report, then stop. It writes nothing new; every number and claim in it comes from a record you read this turn (the session's commits, the runs' `run.json`, task reports, review files, gate and repo-gate logs, the time log, what the session added to the lessons file) or from the conversation itself. A claim with no source is left out.

1. **Handoff**: `Handoff: <note path> (<committed <sha> | local>)`.
2. **What happened**: each run and each piece of work outside runs, one line: what it does, estimate against actual where the time log has both, review rounds and what each found.
3. **What broke**: everything that went wrong, Claude's own mistakes first (a wrong claim, a rule broken, a check skipped, rework, a wasted run), then retries, gate trips, review rejections, blocked tasks and failed gates. Each with its evidence (commit, `file:line`, review file, log) and what was done about it. Nothing is softened or left out because it was fixed.
4. **What went right**: what worked and the evidence for it (a task under estimate, a clean review, a check that caught a real bug).
5. **Lessons**: each lesson the session recorded, one line; then any lesson the session showed that nothing records yet, marked `not recorded`.
6. **Waiting on the human**: open decisions and questions, each with a recommendation.
7. **Next**: the first three items of the handoff, in order.
