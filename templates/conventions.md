# Conventions for this repo

Read by the planner, every implementer and the conformance reviewer at the start of every
idleflow run. Commit this file. Edit it by hand whenever a decision changes, or run
`/idleflow:style` to re-answer the readability question.

## Code style (always on, every mode)

- **Simplest thing that is correct and robust.** No abstraction, option, or layer that the
  acceptance criteria do not need today. Three similar lines beat a helper used once.
- **Plain names, no jargon.** A reader who knows the language but not the codebase should
  understand a function from its name and its first five lines. `customers_without_orders`
  not `cust_filt`; `retry_after_seconds` not `rsec`. No abbreviations the codebase does not
  already use everywhere.
- **One idea per function.** If a docstring needs "and", split it.
- **Early return over nesting.** Handle the error or edge case first, then the main path flat.
- **Comments say why, not what.** Code that needs a "what" comment gets rewritten instead.
- **Boring over clever.** Standard library before a dependency; a loop before metaprogramming;
  a plain dict before a class, until there is behaviour to attach.
- **Handle failures where they happen.** No bare `except`/`catch`, no swallowed errors, no
  silent fallbacks. If something can be missing, say what happens then.
- **Match the repo.** When this file and the surrounding code disagree, the surrounding code
  wins inside an existing module; this file wins for new modules.

## Writing docs, commits and comments (always on)

- **No meta commentary.** Nothing in this repo narrates how it came to be: no "the user
  asked", "as requested", "per our discussion", "I'll now", "after review". State the fact,
  the decision, or the reason. Applies to every `.md`, commit message, pull request, issue,
  session note, research file and code comment. The conformance reviewer rejects on it.
- **Docs describe the code as it is.** A change that makes a sentence wrong fixes the
  sentence in the same commit. Plans live in `prd.md` and `progress.md` "Next", nowhere else.
- **Attribution and releases** follow the `co_author_claude:` and `releases:` lines in `CLAUDE.md`.

## Readability mode

mode: unset

Set to one of these by the first `/idleflow:feature` or `/idleflow:init` run (it asks), or by `/idleflow:style`.

| mode | what the implementer does | best for |
|---|---|---|
| `explicit` | Loops, named intermediate values, one step per line. No comprehensions, chained calls, ternaries or one-liners that do two things. | Teams with mixed experience, teaching codebases, anything a non-programmer reviews. |
| `idiomatic` | The language's native idioms wherever they fit: comprehensions, built-ins, chaining, pattern matching. | Experienced teams who read the language fluently and want less code. |
| `balanced` | An idiom only when it reads as one plain sentence (single clause, no nesting, fits on one line); otherwise explicit. | New projects. The default for an empty repo when nobody is there to answer. |
| `repo` | Write code the way the surrounding code is already written. Before writing, read the file being changed and its nearest neighbours (same directory or layer, and their tests) and match their naming, comment style and density, guard and early-return shape, call style and test structure. No pattern, helper or idiom those files do not already use; a new file copies the closest existing file of its kind. Where the neighbours and the code-style rules above disagree on shape, the neighbours win; failure handling still follows the rules. | Existing codebases with an established style. Offered first on any repo that already has code, and its default when nobody is there to answer. |

Whatever the mode: a construct that takes two readings to understand is wrong in every mode.

## Project docs

docs: unset

`yes` means the repo keeps `prd.md`, `progress.md`, `index.md` and a `CLAUDE.md` block at its
root plus a `docs/` folder (`docs/research/` for library and stack research, `docs/sessions/`
for end-of-session notes), the doc-keeper grounds every doc against the code at the start of
each run, and the retro updates them after every run. Set to `yes` automatically for greenfield
runs or when those files already exist. `no` leaves them out.

docs_in_git: unset

`yes` commits `docs/` so everyone shares the research and session notes. `no` keeps `docs/` out
of git through the file `ignore_in:` names, so they stay local to this machine. Asked once, the
first time docs are turned on.

## Ignore rules

ignore_in: unset

Where idleflow writes its own ignore rules (`.claude/runs/`, a local `docs/`). `exclude` uses
`.git/info/exclude`: local to this clone, so nothing about idleflow appears in a committed file.
`gitignore` uses `.gitignore`: shared with every clone and visible to everyone who reads the repo.
Until it is answered, rules go to `.git/info/exclude`. A stack's own entries (`node_modules/`,
`.venv/`, `dist/`, `.env`) always go in `.gitignore`, because every clone needs them.

## Pushback

Agents question a decision when the evidence says it is wrong: the conflict in one sentence,
the evidence with its path or URL, a better option with its cost. Once, then the human's call
stands and the reason is recorded. No pushback without evidence; no agreement without checking.

## Tooling

Skills, plugins and workflows accepted from the tooling advisor, one line each, with the job
they cover. Full detail in `docs/research/tooling.md`. Missing skills are requested with
`/idleflow:skills-feedback`, idleflow problems reported with `/idleflow:plugin-feedback`.

<!-- tooling start -->

## Stack decisions

Accepted proposals from the stack advisor and libraries chosen from the library scout's
research, one line each. The planner treats these as constraints; implementers may not
introduce a tool or a hand-written replacement that contradicts them. Declined items are
listed too so they are not proposed again.

<!-- stack decisions start -->
