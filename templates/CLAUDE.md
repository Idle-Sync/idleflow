<!-- idleflow start -->
# Working rules for Claude Code in this repo

Written by idleflow on the first run; humans own it afterwards. Keep this block; edit it when
a rule changes. Everything here applies to every Claude Code session in this repo, not only
to `/idleflow:*` runs.

## Start of every session

1. Read `progress.md`, then the newest two files in `docs/sessions/` (`s_0001.md`, `s_0002.md`, …).
   That is where the last sessions left off. Do not start from the code; start from these.
2. **Ground the docs before anything else.** Check every claim in `index.md`, `prd.md`,
   `progress.md`, `README.md`, this file and `docs/**/*.md` against the code: a path that no
   longer exists, a command that no longer runs, a feature described that is not there or
   works differently, a "next step" that already landed. Fix each stale claim so it matches
   the code (never the other way round), then commit with the message `docs: ground stale
   claims`. Only then take up the task. If nothing is stale, say so in one line and move on.
3. Read `.claude/conventions.md`. It holds the code-style rules, the readability mode and the
   stack decisions; they are not optional.

## End of every session

1. Write `docs/sessions/s_NNNN.md` (next number, four digits) from `docs/sessions/TEMPLATE.md`:
   what was done, which files changed and why, what is next, open questions. Short; paths, not prose.
2. Add an entry at the top of `progress.md` and bring `index.md` up to date if any file or
   directory a newcomer must know about was added, moved or removed.
3. Commit the notes together with the work.

## No doc goes stale

A change that makes any sentence in any `.md` file wrong updates that sentence in the same
commit. Docs describe the code as it is, never as it is planned to be; plans live in `prd.md`
under "Nice to have" and "Milestones", and in `progress.md` under "Next".

## Do not reinvent the wheel

Before writing code for a capability (animation, charts, parsing, auth, dates, HTTP, state,
validation, …):

1. Check `docs/research/` — it may already be settled there.
2. Check what the project already depends on; use that first.
3. Otherwise look for an established library and write up the options in
   `docs/research/<topic>.md` with sources (official docs, the repository, one independent
   source each), then ask the human which to use. Hand-written canvas code when p5.js or
   three.js fits, a hand-rolled date parser, a home-made HTTP client: these are findings in
   review, not style choices.

## How code is written here

See `.claude/conventions.md`. The short version: the simplest thing that is correct and
robust, plain names a newcomer can read, one idea per function, failures handled where they
happen, boring over clever.

## Commands

- Install: `<command>`
- Test: `<command>`
- Run: `<command>`
<!-- idleflow end -->
