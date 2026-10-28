# idleflow

A Claude Code plugin that turns "fix this" or "build this" into a bounded pipeline:

```
issue ─► explore (Sonnet) ─► classify size, risk, new dependency (Haiku) ─► plan (Fable)
      ─► debate, size L or high risk: red team ⇄ cost critic, 2 rounds (Opus×2) ─► plan revised (Fable)
      ─► build: ≤4 implementers, one git worktree each, file-ownership enforced by hook (Sonnet / Opus)
      ─► diff gate: >1500 hand-written lines ⇒ auditor decides split / accept / reject (Sonnet)
      ─► review: correctness (Opus) + conformance (Sonnet), per task
      ─► merge in plan order, run suite ─► retro writes ≤1 lesson (Haiku)
```

For an empty folder, `/idleflow:init` runs the first session instead: a four-round brainstorm, a **market-research** agent (competitors, what their users complain about, table stakes, a viability verdict, every claim with a URL) into `docs/market-research.md`, the repo's rules (readability mode, whether Claude is co-authored on commits, tagged GitHub releases or not, docs in git or not), stack and library research, a PRD written by the planner and approved by the human, the project docs, the first commit and optionally the GitHub repo. It hands off to `/idleflow:feature "Milestone 1"`. For a project that already has code, `/idleflow:setup` does the onboarding part: it maps the code, asks the repo's rules once, records the stack the project already uses rather than proposing a new one, offers tooling, and commits the setup for the team. `/idleflow:doctor` checks a repo's setup and whether a newer idleflow is out at any time.

Around the pipeline, five things that keep a repo honest:

- **Not a yes machine.** When a request or an answer conflicts with the code, the tests, a research file or a source an agent can cite, it says so once, with the evidence and a better option, then does what the human decides and records why. Pushback without evidence is left out; agreement without checking is rejected in review.

- **Code style is a contract, not advice.** `.idleflow/conventions.md` (committed) holds the KISS rules — simplest correct thing, plain names a newcomer can read, one idea per function, failures handled where they happen — and a **readability mode** (`repo` / `balanced` / `explicit` / `idiomatic`) that decides whether a list comprehension or a loop is the right shape. On a repo that already has code, `repo` is offered first with a snippet from the repo itself: implementers copy the style of the files next to the change. The first run asks once, with pros and cons; `/idleflow:style` changes it later. Implementers write to it and the conformance reviewer rejects on it.
- **Research before code.** On greenfield runs and changes that add a dependency, a **stack advisor** scans the repo and the machine (pyproject vs requirements.txt, venv, Docker present, lockfiles, linters, CI), a **researcher** checks several internet sources per candidate with a URL on every claim, and the human accepts or declines each proposal. A **library scout** does the same for the capabilities the change needs (canvas animation → p5.js / three.js, not hand-rolled canvas code), writing `docs/research/<capability>.md`. Repos at or above `LARGE_REPO_LOC` hand-written code lines get a proposal for a code map (Graphify, Serena MCP, Sourcegraph, ctags).
- **No meta commentary, ever.** The generated `CLAUDE.md` and `.idleflow/conventions.md` ban process narration ("the user asked", "as requested", "I'll now") from every doc, commit, PR, comment and note in the repo, and record whether commits carry a `Co-Authored-By: Claude` trailer (`co_author_claude: yes|no`; footers never). The conformance reviewer rejects on both.
- **The right tooling, not hand-rolled.** A tooling advisor inventories installed plugins and skills, checks the [Idle-Sync/skills](https://github.com/Idle-Sync/skills) catalogue against what is installed, and proposes the skills, marketplace plugins and workflows the project will use often; accepted items are installed, missing ones become `/idleflow:skills-feedback` requests. `/idleflow:plugin-feedback` reports idleflow's own bugs with the run's evidence attached.
- **It reports its own gaps.** Any agent that finds the plugin lacks an input, step, tool or config knob it needed appends a `plugin_gap:` line to `.idleflow/runs/active/gaps.md` instead of working around it. At the end of a run the orchestrator lists them and asks once whether to open them as issues on Idle-Sync/idleflow from the human's GitHub account; nothing is filed without that yes. On greenfield runs the stack advisor always proposes quality tooling per language (ruff, mypy or pyright, pytest and pre-commit for Python; biome or eslint plus prettier, strict tsc and vitest for TypeScript; gofmt and golangci-lint for Go; rustfmt and clippy for Rust, and so on), grounded by the researcher like every other proposal.
- **No doc goes stale.** With project docs on (automatic for greenfield), the repo gets `prd.md` (the product), `progress.md` (milestones as checkboxes the retro ticks, plus the log), `index.md`, a `CLAUDE.md` block and `docs/sessions/`. A **doc-keeper** runs before every run, checks each claim in those docs against the code, fixes what is stale and commits. The retro writes a session note and updates progress and index after every run. The generated `CLAUDE.md` makes plain Claude Code sessions follow the same start-and-end protocol, and `/idleflow:endsession` closes a working session with a note whose "Next" lists, in order, what the next session does first: push, CI, release, restarts, open deviations.

## What it adds over plain Claude Code

| Plain Claude Code | With idleflow |
|---|---|
| One session plans, codes and checks its own work | Sonnet explores, Fable plans, two Opus critics attack large or risky plans, implementers build, two independent reviewers gate each task |
| One working tree; parallel work collides | One git worktree per task; a hook blocks edits outside the files a task owns |
| Size of a change is unchecked | A diff gate sends oversized tasks to an auditor that accepts, splits or rejects |
| Each session starts fresh | Lessons from every run feed the next plan; conventions and settings are committed for the team |
| Status lives in people's heads | Milestones as checkboxes in `progress.md`, `/idleflow:progress`, session handoffs, docs grounded against the code |
| Settings are per person | `/idleflow:customize` per repo, shared through git; `/idleflow:doctor` checks setup and updates |

## Decisions baked in (and where to change them)

| Decision | Value | Where |
|---|---|---|
| Plan context | Sonnet explores, Fable plans from `context.md` | `agents/explorer.md`, `agents/planner.md` |
| Debate | asymmetric roles, hard cap 2 rounds; the human picks which cuts and contested points to accept, the planner adjudicates the rest | `agents/red-team.md`, `agents/cost-critic.md`, `DEBATE_ROUNDS` |
| Sizing | Haiku reports size, risk and new dependency; size sets implementers and reviewers, risk (or size L) the debate, a new dependency the stack and library research; an S overrun adds the conformance reviewer | `agents/classifier.md`, `SIZE_*` in conf |
| Fan-out | ≤4 implementers, partitioned by file globs, Sonnet default / Opus when plan says | `MAX_IMPLEMENTERS`, `model:` per task in plan |
| Diff gate | 1500 code lines per task (+300 slack); `.md`, `.txt`, lockfiles, generated excluded | `DIFF_LIMIT`, `DIFF_SLACK`, `DIFF_EXCLUDE` |
| Retry | one per task, on Opus, then stop and ask | `MAX_RETRIES`, steps 5 and 7 of `commands/feature.md` |
| Tests | `tests_first: true` forced wherever entry points have no tests | planner §3, conformance reviewer §4 |
| Mutation sweep | implementers break their own change on purpose; a fault no test catches needs a test or a reason | `STEP_MUTATION`, plan `mutation:`, implementer, correctness reviewer |
| Placeholders | code that cannot do its job yet fails loudly; a plausible default is a blocking finding | implementer, correctness reviewer |
| Checkable findings | each review finding says whether a deterministic check would have caught it; repeats become a lesson | reviewers, `agents/retro.md` |
| Lessons | per repo, `.idleflow/lessons.md` or `docs/lessons.md` (`lessons_in:`), ≤1 per run | `agents/retro.md`, `run.sh path lessons` |
| Metrics | `.idleflow/runs/log.jsonl` only (no OTEL yet) | `scripts/run.sh finish` |
| Priority | quality > tokens > time | retry on Opus; `opus` allowed per task; critics on Opus |
| Readability mode | asked once per repo; `repo` on existing code and `balanced` on an empty repo when nobody answers | `.idleflow/conventions.md`, `commands/style.md` |
| Ignore rules | idleflow's own paths go to `.git/info/exclude` or `.gitignore`, asked once; exclude until answered | `ignore_in:` in conventions.md, `run.sh ignore` |
| Stack / library research | greenfield or a new dependency; ≥3 sources per candidate, URL on every claim | `agents/stack-advisor.md`, `agents/stack-researcher.md`, `agents/library-scout.md` |
| Large repo | ≥ 100 000 hand-written code lines → code-map proposal | `LARGE_REPO_LOC`, `run.sh loc` |
| Attribution, releases, meta commentary | asked by `/idleflow:init`, recorded in `CLAUDE.md` | `templates/CLAUDE.md`, `agents/review-conform.md` §7 |
| Market research | `/idleflow:init` only; verdict viable / viable-if / crowded / weak | `agents/market-researcher.md` |
| Tooling | skills from Idle-Sync/skills, marketplace plugins, workflows; installed only when accepted by name | `agents/tooling-advisor.md`, "Tooling" in conventions.md |
| Pushback | once, with evidence, then the human's call stands | `templates/CLAUDE.md`, planner, both orchestrators |
| Project docs | on for greenfield; doc-keeper before, retro after every run | `docs:` in conventions.md, `agents/doc-keeper.md`, `agents/retro.md`, `templates/CLAUDE.md` |

## Working as a team

`.idleflow/` (conventions, lessons, settings, declined suggestions), `progress.md` and the session notes
are committed, so everyone who pulls plans with the same rules and lessons. What would otherwise collide:

- **Concurrent additions.** `snapshot` sets git's built-in `merge=union` for the lessons file, `progress.md`
  and `.idleflow/suggestions.md`, so two people's new lines merge instead of conflicting. The trade: when
  both edit the same lines (two people ticking neighbouring milestone boxes), union keeps both versions;
  the doctor reports a milestone item listed twice so one line can be kept.
- **Session notes.** Named `s_<YYYYMMDD-HHMM>-<author>.md` (`run.sh session-name`), never by a running
  number two people could both pick.
- **A stale base.** `/idleflow:feature` checks `run.sh behind` first and offers to pull, so a run plans with
  the team's latest lessons and settings.
- **Who did what.** `run.json` records `by`; merge commits carry the run id; `/idleflow:progress` shows the
  whole team's landed work from git history, plus the milestones in `progress.md`.
- **Teammates without idleflow.** `run.sh team-install` adds idleflow to the committed `.claude/settings.json`
  (`extraKnownMarketplaces` and `enabledPlugins`); Claude Code loads it for each teammate once they trust
  the folder. The doctor warns when more than one person commits and it is not set.

## Fitting a repo that has its own rules

Conventions "Repo fit" and "Records" let idleflow work inside a repo's existing process instead of
beside it. Every key is optional and missing keys keep the defaults, so older repos change nothing.

| Key | What it does |
|---|---|
| `worktrees_in: inside` | Task worktrees in `.idleflow/worktrees/` (ignored) instead of a sibling folder |
| `worktree_setup: <command>` | Run in each new worktree before the implementer starts (`$MAIN`, `$WORKTREE` set). Runs only as committed and after each person approves that exact text (`run.sh approve`, local git config); fails loudly; may not change tracked files |
| `progress_file`, `index_file`, `sessions_dir`, `time_log`, `lessons_in: <path>` | Use the records the repo already keeps |
| `index_rewrite: no` | The retro leaves the index to the repo's own process |
| `session_names: numbered` | Keep a repo's `s_0001.md` numbering |
| `gate: <command>` | The repo's own check is the definition of done: run on the base first (old failures are not blamed on the run), by implementers and the correctness reviewer, and after merge. Same approval rule as `worktree_setup` |
| `commit_format: conventional` | Task, finish and merge commits as Conventional Commits (subject at most 72 characters, ids in the body) |
| `shared_files: <paths>` | Files every task may add its own lines to (a changelog, an index the repo's checks need a row in), merged by union |

## Customizing one project

Every number in `config/idleflow.conf` is a default. `/idleflow:customize` overrides it for one repo in
`.idleflow/idleflow.conf`, turns a step on or off (`STEP_DEBATE`, `STEP_STACK`, `STEP_LIBRARIES`,
`STEP_TOOLING`, `STEP_DOC_KEEPER`), sets an agent's model (`MODEL_<AGENT>`), adds instructions to an
agent (`.idleflow/agents/<agent>.md`), or replaces an agent's prompt (`.claude/agents/idleflow-<agent>.md`,
with a base copy so `/idleflow:doctor` can merge later plugin updates into it). A replaced agent keeps the
built-in output contract. Everything is committed, so the team shares it. The project file is parsed, never
sourced: a key outside the list in `scripts/conf.sh`, or a value out of range, is skipped and reported.

Each customization can be reported as a comment on one issue per setting on Idle-Sync/idleflow
(`customization: DIFF_LIMIT`, `customization: prompt planner`, ...). The first time, the project answers
report / always / never; `always` and `never` are saved per person in the clone's git config
(`idleflow.reportCustomizations`), never committed, so one teammate's answer never posts from another's account. Instruction text and
prompt diffs are shown before every post.

## Layout

```
.claude-plugin/plugin.json      manifest
.claude-plugin/marketplace.json lets the repo itself be added as a marketplace
commands/feature.md             the orchestrator — the run procedure lives here
procedures/repo-setup.md        setup steps R1–R6 shared by feature and init (mode, docs, stack, libraries, tooling, snapshot)
commands/fix.md                 same, bug-biased
commands/init.md                first session for an empty folder: brainstorm, market research, rules, PRD, first commit
commands/style.md               set or change the readability mode
commands/skills-feedback.md     open a skill request on github.com/Idle-Sync/skills
commands/plugin-feedback.md     report a bug or idea about idleflow on github.com/Idle-Sync/idleflow
commands/endsession.md          end a working session: handoff note with ordered next steps, progress entry, commit
commands/setup.md               set idleflow up in a project that already has code; fills only the gaps on one already set up
commands/progress.md            where the project stands: milestones ticked and open, who landed what, what is next, what waits on a human
commands/customize.md           per-project settings, step toggles, agent models, extra instructions, agent replacement; reports each change
commands/doctor.md              check the repo's idleflow setup and for a newer release; offers the safe fixes
agents/                         one file per role; frontmatter sets the model
hooks/hooks.json                PreToolUse → ownership-guard
scripts/run.sh                  run lifecycle: new / wt / own / get / set / inc / report / gate / merge / snapshot / finish / loc / conf,
                                plus path / migrate / doctor / update-check
scripts/diff-gate.sh            counts hand-written code lines vs base, emits JSON verdict
scripts/ownership-guard.sh      the hook; blocks edits outside a task's globs
scripts/rt.sh                   picks Python or Node, whichever is installed
scripts/conf.sh                 loads config/idleflow.conf, then a project's .idleflow/idleflow.conf (parsed, never run)
scripts/idleflow.py             the JSON / gate / guard logic (Python)
scripts/idleflow.js             the same program in Node; keep the two in sync
scripts/selftest.sh             end-to-end check of the scripts in a throwaway repo
config/idleflow.conf            every number the workflow uses
templates/                      plan.md, context.md, lessons.md, conventions.md, prd.md, progress.md, install-note.md,
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
.idleflow/lessons.md                 commit this
.idleflow/conventions.md             commit this: style rules, readability mode, stack decisions
prd.md  progress.md  index.md      repo root, when docs are on; humans and the retro both edit them
CLAUDE.md                          the idleflow block: start-of-session doc grounding, end-of-session notes
docs/research/<capability>.md      library and stack research with sources
docs/sessions/s_<time>-<author>.md one note per run or session, named so teammates never collide; ignored or committed, asked once
.idleflow/runs/active/               the run in progress (a plain directory; renamed to <id>/ on finish)
.idleflow/runs/active/gaps.md        plugin_gap lines agents append; asked about before every finish
.idleflow/runs/<id>/                 ignored (.git/info/exclude or .gitignore, asked once); issue, context, plan, debate/, tasks/, review/, run.json
.idleflow/runs/log.jsonl             one line per finished run — tokens aren't captured yet, but
                                   size, retries, gate trips and review findings are
.idleflow/runs/config-proposals.md   the retro's customization suggestions, with evidence; offered once at the end of a run
.idleflow/suggestions.md             suggestions the team declined, so they are not offered again; commit this
<repo>__wt/<task-id>               sibling directory holding task worktrees during a run
```

## Install

```
claude plugin install idleflow --marketplace Idle-Sync/idleflow
```

Older Claude Code: `claude plugin marketplace add Idle-Sync/idleflow` then `claude plugin install idleflow@idlesync`. For a local checkout, or to hand the whole setup to Claude Code (*"read setup.md and set this up globally"*), see `setup.md`. To publish a new version, see `PUBLISHING.md`.

## Known gaps

- Token counts per phase aren't captured; `/cost` after a run is the stopgap. OTEL export is planned.
- `${CLAUDE_PLUGIN_ROOT}` in command files assumes plugin install; Option B in setup.md rewrites it.
- Ownership globs use fnmatch rules (`*` crosses `/`); `src/**` is the usual shape. Diff-gate excludes use git pathspec globs and are all `**/`-prefixed so they match at any depth.
- `model: fable` in agent frontmatter depends on account access; setup.md step 3 checks and falls back.
- The orchestrator is a prompt, not code. It will occasionally drift. The "Rules you never break" block at the bottom of `commands/feature.md` is the first thing to tighten when it does.
