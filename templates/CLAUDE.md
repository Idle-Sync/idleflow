<!-- idleflow start -->
# Working rules for Claude Code in this repo

Humans own this block: keep it, and edit it when a rule changes. Everything here applies to
every Claude Code session in this repo, not only to `/idleflow:*` runs.

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

`/idleflow:endsession` writes the note and the `progress.md` entry and commits them, with "Next"
as the ordered handoff; it refuses while a run is still active. Commit the work itself first.

1. Write `docs/sessions/s_NNNN.md` (next number, four digits) from `docs/sessions/TEMPLATE.md`:
   what was done, which files changed and why, what is next, open questions. Short; paths, not prose.
2. Add an entry at the top of `progress.md` and bring `index.md` up to date if any file or
   directory a newcomer must know about was added, moved or removed.
3. Commit the notes; the work they describe is already committed.

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

## Disagree when the evidence says so

An agent in this repo is not a yes machine. When a request, an answer or a decision conflicts
with the code, the tests, `docs/research/`, `docs/market-research.md`, `.claude/conventions.md`
or a source it can cite, it says so before acting: the conflict in one sentence, the evidence
with its path or URL, and a better option with its cost. Once. Then it does what the human
decides and records the decision and the reason, not the argument. Pushback without evidence
is an opinion and is left out; agreement without checking is worse.

## Tooling

Skills, plugins and workflows chosen for this project are listed in `docs/research/tooling.md`
and under "Tooling" in `.claude/conventions.md`. A recurring job with no tool for it is a
request, not a reason to hand-write one: `/idleflow:skills-feedback "<the job>"` opens an
issue on the IdleSync skills catalogue; `/idleflow:plugin-feedback "<what went wrong>"` reports
a problem with idleflow itself. Agents that hit a gap in idleflow during a run write a `plugin_gap:`
line and the run asks, once, whether to report it; nothing is filed without a yes.

## How code is written here

See `.claude/conventions.md`. The short version: the simplest thing that is correct and
robust, plain names a newcomer can read, one idea per function, failures handled where they
happen, boring over clever.

## No meta commentary, anywhere

No file in this repo narrates how it came to be. Not in docs, commit messages, pull requests,
issues, code comments, session notes or research files. Banned: "the user asked", "as
requested", "per our discussion", "user said so", "I'll now", "using skill X", "after
reviewing", "Claude decided". Write the fact, the decision, or the reason. A session note says
"Switched auth to cookie sessions: the token refresh path leaked on logout", not "The user
wanted cookies so I switched". Reviewers reject a diff for this the same as for a bug.

## Git attribution

co_author_claude: <yes|no>

`no`: commits carry only the human's identity. Never add a `Co-Authored-By: Claude` trailer
and never add a "Generated with Claude Code" footer to a commit, pull request or anything else.
`yes`: every commit an agent makes ends with `Co-Authored-By: Claude <noreply@anthropic.com>`;
still no footers anywhere.

## Releases

releases: <github-tagged | none>

`github-tagged`: semantic versions. When a `prd.md` milestone completes and the suite is green,
tag `vX.Y.Z` (minor bump per milestone, patch for fixes, major when a public interface breaks)
and publish a GitHub release whose notes are that milestone's `progress.md` entries. Nothing is
tagged automatically; a run that completes a milestone proposes the tag and a human runs:

```
git tag -a vX.Y.Z -m "vX.Y.Z: <milestone>" && git push --tags
gh release create vX.Y.Z --title "vX.Y.Z — <milestone>" --notes-file <notes>
```

`none`: local git only; nothing is tagged. Change this line when that changes.

## Commands

- Install: `<command>`
- Test: `<command>`
- Run: `<command>`
<!-- idleflow end -->
