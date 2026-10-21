# idleflow

A Claude Code plugin that turns "fix this" or "build this" into a bounded pipeline:

```
issue ─► explore (Sonnet) ─► classify S/M/L (Haiku) ─► plan (Fable)
      ─► debate: red team ⇄ cost critic, 2 rounds (Opus×2) ─► plan revised (Fable)
      ─► build: ≤4 implementers, one git worktree each, file-ownership enforced by hook (Sonnet / Opus)
      ─► diff gate: >1500 hand-written lines ⇒ auditor decides split / accept / reject (Sonnet)
      ─► review: correctness (Opus) + conformance (Sonnet), per task
      ─► merge in plan order, run suite ─► retro writes ≤1 lesson (Haiku)
```

Around the pipeline, three things that keep a repo honest:

- **Code style is a contract, not advice.** `.claude/conventions.md` (committed) holds the KISS rules — simplest correct thing, plain names a newcomer can read, one idea per function, failures handled where they happen — and a **readability mode** (`explicit` / `idiomatic` / `balanced`) that decides whether a list comprehension or a loop is the right shape. The first run asks once, with pros and cons; `/idleflow:style` changes it later. Implementers write to it and the conformance reviewer rejects on it.
- **Research before code.** On greenfield and M/L runs, a **stack advisor** scans the repo and the machine (pyproject vs requirements.txt, venv, Docker present, lockfiles, linters, CI), a **researcher** checks several internet sources per candidate with a URL on every claim, and the human accepts or declines each proposal. A **library scout** does the same for the capabilities the change needs (canvas animation → p5.js / three.js, not hand-rolled canvas code), writing `docs/research/<capability>.md`. Repos at or above `LARGE_REPO_LOC` hand-written code lines get a proposal for a code map (Graphify, Serena MCP, Sourcegraph, ctags).
- **No doc goes stale.** With project docs on (automatic for greenfield), the repo gets `prd.md`, `progress.md`, `index.md`, a `CLAUDE.md` block and `docs/sessions/`. A **doc-keeper** runs before every run, checks each claim in those docs against the code, fixes what is stale and commits. The retro writes a session note and updates progress and index after every run. The generated `CLAUDE.md` makes plain Claude Code sessions follow the same start-and-end protocol.

## Decisions baked in (and where to change them)

| Decision | Value | Where |
|---|---|---|
| Plan context | Sonnet explores, Fable plans from `context.md` | `agents/explorer.md`, `agents/planner.md` |
| Debate | asymmetric roles, hard cap 2 rounds, planner adjudicates | `agents/red-team.md`, `agents/cost-critic.md`, `DEBATE_ROUNDS` |
| Sizing | Haiku classifies; S skips debate; overrun bumps to M retroactively | `agents/classifier.md`, `SIZE_*` in conf |
| Fan-out | ≤4 implementers, partitioned by file globs, Sonnet default / Opus when plan says | `MAX_IMPLEMENTERS`, `model:` per task in plan |
| Diff gate | 1500 code lines per task (+300 slack); `.md`, `.txt`, lockfiles, generated excluded | `DIFF_LIMIT`, `DIFF_SLACK`, `DIFF_EXCLUDE` |
| Retry | one, on Opus, then stop and ask | `MAX_RETRIES`, step 7 of `commands/feature.md` |
| Tests | `tests_first: true` forced wherever entry points have no tests | planner §3, conformance reviewer §3 |
| Lessons | per repo, `.claude/lessons.md`, ≤1 per run | `agents/retro.md` |
| Metrics | `.claude/runs/log.jsonl` only (no OTEL yet) | `scripts/run.sh finish` |
| Priority | quality > tokens > time | retry on Opus; `opus` allowed per task; critics on Opus |
| Readability mode | asked once per repo; `balanced` when nobody answers | `.claude/conventions.md`, `commands/style.md` |
| Stack / library research | greenfield or M/L; ≥3 sources per candidate, URL on every claim | `agents/stack-advisor.md`, `agents/stack-researcher.md`, `agents/library-scout.md` |
| Large repo | ≥ 100 000 hand-written code lines → code-map proposal | `LARGE_REPO_LOC`, `run.sh loc` |
| Project docs | on for greenfield; doc-keeper before, retro after every run | `docs:` in conventions.md, `agents/doc-keeper.md`, `agents/retro.md`, `templates/CLAUDE.md` |

## Layout

```
.claude-plugin/plugin.json      manifest
.claude-plugin/marketplace.json lets the repo itself be added as a marketplace
commands/feature.md             the orchestrator — the whole procedure lives here
commands/fix.md                 same, bug-biased
commands/style.md               set or change the readability mode
agents/                         one file per role; frontmatter sets the model
hooks/hooks.json                PreToolUse → ownership-guard
scripts/run.sh                  run lifecycle: new / wt / own / set / inc / gate / merge / finish / conf
scripts/diff-gate.sh            counts hand-written code lines vs base, emits JSON verdict
scripts/ownership-guard.sh      the hook; blocks edits outside a task's globs
scripts/rt.sh                   picks Python or Node, whichever is installed
scripts/idleflow.py             the JSON / gate / guard logic (Python)
scripts/idleflow.js             the same program in Node; keep the two in sync
scripts/selftest.sh             end-to-end check of the scripts in a throwaway repo
config/idleflow.conf            every number the workflow uses
templates/                      plan.md, context.md, lessons.md, conventions.md, prd.md, progress.md,
                                index.md, session.md, CLAUDE.md
setup.md                        global install, written for Claude Code to execute
PUBLISHING.md                   validate, push to GitHub, install elsewhere, release updates
```

## Runtime

The bash scripts need either **Python ≥ 3.8** or **Node ≥ 18** on `PATH`; `scripts/rt.sh` tries
`python3`, then `python`, then `node`, and `IDLEFLOW_RUNTIME=node` (or `python`, or a full path)
pins one. `bash scripts/run.sh conf` prints which one is in use. On Windows, bash comes from Git for
Windows; paths in every form (`D:\x`, `D:/x`, `/d/x`) are normalised before comparison.

```
bash scripts/selftest.sh                      # exercises every script against a scratch repo
IDLEFLOW_RUNTIME=node   bash scripts/selftest.sh
IDLEFLOW_RUNTIME=python bash scripts/selftest.sh
```

## Per-repo state

```
.claude/lessons.md                 commit this
.claude/conventions.md             commit this: style rules, readability mode, stack decisions
prd.md  progress.md  index.md      repo root, when docs are on; humans and the retro both edit them
CLAUDE.md                          the idleflow block: start-of-session doc grounding, end-of-session notes
docs/research/<capability>.md      library and stack research with sources
docs/sessions/s_NNNN.md            one note per run or session; gitignored or committed, asked once
.claude/runs/active/               the run in progress (a plain directory; renamed to <id>/ on finish)
.claude/runs/<id>/                 gitignored; issue, context, plan, debate/, tasks/, review/, run.json
.claude/runs/log.jsonl             one line per finished run — tokens aren't captured yet, but
                                   size, retries, gate trips and review findings are
.claude/runs/config-proposals.md   retro's suggested threshold changes; apply by hand
<repo>__wt/<task-id>               sibling directory holding task worktrees during a run
```

## Install

See `setup.md`, or hand it to Claude Code: *"read setup.md and set this up globally"*. To publish, see `PUBLISHING.md`.

## Known gaps (v0.1)

- Token counts per phase aren't captured; `/cost` after a run is the stopgap. OTEL export is the planned v0.2.
- `${CLAUDE_PLUGIN_ROOT}` in command files assumes plugin install; Option B in setup.md rewrites it.
- Ownership globs use fnmatch rules (`*` crosses `/`); `src/**` is the usual shape. Diff-gate excludes use git pathspec globs and are all `**/`-prefixed so they match at any depth.
- `model: fable` in agent frontmatter depends on account access; setup.md step 3 checks and falls back.
- The orchestrator is a prompt, not code. It will occasionally drift. The "Rules you never break" block at the bottom of `commands/feature.md` is the first thing to tighten when it does.
