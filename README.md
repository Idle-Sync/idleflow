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

For an empty folder, `/idleflow:init` runs the first session instead: a four-round brainstorm, a **market-research** agent (competitors, what their end users complain about, table stakes, a viability verdict, every claim with a URL) into `docs/market-research.md`, the repo's rules (readability mode, whether Claude is co-authored on commits, tagged GitHub releases or not, docs in git or not), stack and library research, a PRD written by the planner and approved by the human, the project docs, the first commit and optionally the GitHub repo. It hands off to `/idleflow:feature "Milestone 1"`. For a project that already has code, `/idleflow:setup` does the onboarding part: it maps the code, asks the repo's rules once, records the stack the project already uses rather than proposing a new one, offers tooling, and commits the setup for the team. `/idleflow:doctor` checks a repo's setup and whether a newer idleflow is out at any time.

Around the pipeline, five things that keep a repo honest:

- **Not a yes machine.** When a request or an answer conflicts with the code, the tests, a research file or a source an agent can cite, it says so once, with the evidence and a better option, then does what the human decides and records why. Pushback without evidence is left out; agreement without checking is rejected in review.

- **Code style is a contract, not advice.** `.idleflow/conventions.md` (committed) holds the KISS rules — simplest correct thing, plain names a newcomer can read, one idea per function, failures handled where they happen — and a **readability mode** (`repo` / `balanced` / `explicit` / `idiomatic`) that decides whether a list comprehension or a loop is the right shape. On a repo that already has code, `repo` is offered first with a snippet from the repo itself: implementers copy the style of the files next to the change. The first run asks once, with pros and cons; `/idleflow:style` changes it later. Implementers write to it and the conformance reviewer rejects on it.
- **Research before code.** On greenfield runs and changes that add a dependency, a **stack advisor** scans the repo and the machine (pyproject vs requirements.txt, venv, Docker present, lockfiles, linters, CI), a **researcher** checks several internet sources per candidate with a URL on every claim, and the human accepts or declines each proposal. A **library scout** does the same for the capabilities the change needs (canvas animation → p5.js / three.js, not hand-rolled canvas code), writing `docs/research/<capability>.md`. Repos at or above `LARGE_REPO_LOC` hand-written code lines get a proposal for a code map (Graphify, Serena MCP, Sourcegraph, ctags).
- **No meta commentary, ever.** The generated `CLAUDE.md` and `.idleflow/conventions.md` ban process narration ("the user asked", "as requested", "I'll now") from every doc, commit, PR, comment and note in the repo, and record whether commits carry a `Co-Authored-By: Claude` trailer (`co_author_claude: yes|no`; footers never). The conformance reviewer rejects on both. <!-- vocab: allow -->
- **The right tooling, not hand-rolled.** A tooling advisor inventories installed plugins and skills, checks the [Idle-Sync/skills](https://github.com/Idle-Sync/skills) catalogue against what is installed, and proposes the skills, marketplace plugins and workflows the project will use often; accepted items are installed, missing ones become `/idleflow:skills-feedback` requests. `/idleflow:plugin-feedback` reports idleflow's own bugs with the run's evidence attached, written to the same blueprint as every other issue ([ISSUES.md](ISSUES.md)).
- **It reports its own gaps.** Any agent that finds the plugin lacks an input, step, tool or config knob it needed appends a `plugin_gap:` line to `.idleflow/runs/active/gaps.md` instead of working around it. At the end of a run the orchestrator lists them and asks once whether to open them as issues on Idle-Sync/idleflow from the human's GitHub account; nothing is filed without that yes. On greenfield runs the stack advisor always proposes quality tooling per language (ruff, mypy or pyright, pytest and pre-commit for Python; biome or eslint plus prettier, strict tsc and vitest for TypeScript; gofmt and golangci-lint for Go; rustfmt and clippy for Rust, and so on), grounded by the researcher like every other proposal.
- **No doc goes stale.** With project docs on (automatic for greenfield), the repo gets `prd.md` (the product), `progress.md` (milestones as checkboxes the retro ticks, plus the log), `index.md`, `vocabulary.md` (one term per concept, which every run checks the docs it changes against), a `CLAUDE.md` block and `docs/sessions/`. A **doc-keeper** runs before every run, checks each claim in those docs against the code, fixes what is stale and commits. The retro writes a session note and updates progress and index after every run. The generated `CLAUDE.md` makes plain Claude Code sessions follow the same start-and-end protocol, and `/idleflow:endsession` closes a working session with a note whose "Next" lists, in order, what the next session does first: push, CI, release, restarts, open deviations.

## Frontend design, built in

For work an end user sees (the classifier reports `ui: true`, or `STEP_DESIGN=on`), the run designs before it plans:

- **`idleflow:designer`** reads idleflow's own design handbook (`procedures/design.md`) and reference data
  (`procedures/design-data.md`: type pairings, scales, colour recipes, contrast formula, motion values,
  checklists by screen type). It writes or extends the repo's lasting design system (`docs/design-system.md`,
  or `.idleflow/design-system.md` without docs), in the sections of `templates/design-system.md`: a direction,
  tokens with measured contrast for light and dark, components, the looks the project avoids. Only a project
  with screens people see, a frontend or a game, keeps one: `/idleflow:init` has the human pick its direction,
  `/idleflow:setup` records it from the UI the code already has (`run.sh ui` says whether there is one), and
  the doctor reports a UI repo without it. For this run it writes `design.md`: a spec per screen with layout, hierarchy, every state,
  motion and accessibility, plus the issue's requirements that no screen shows (an API payload, CLI output),
  which the plan gives to the tasks that build those surfaces. Token work becomes the plan's first task.
- **Directions to choose from.** On a greenfield run, or in a repo with no design system yet, the designer first
  writes three distinct directions, each with its tokens and one self-contained HTML page showing the palette,
  the type pairing and one screen. The human picks one, or rejects them all and says why, and the design system
  is written from the pick. `STEP_DESIGN_OPTIONS` turns this on or off whenever the design step runs.
- **Libraries** it would use (an animation library such as GSAP, a component set such as shadcn/ui) go to the
  library step for research and the human's yes; it never installs anything.
- **`idleflow:review-design`** reviews every `ui` task against the spec and tokens, checks accessibility and the
  signs of a generic look, and, when a browser tool is available and the repo has an approved `preview:`
  command, renders the changed screens at 390 and 1440 px and reviews the images. For an app that runs
  only from the main checkout (`preview_in: main`), it checks the merged screens, and each
  `verify: browser after merge` criterion, once after the last merge (`run.sh preview main`).
- **`idleflow:review-api`** reviews every `api` task (an HTTP, GraphQL or RPC operation, a library's public
  symbol, a CLI used from scripts, or an event or webhook payload) for the developers who call it, against the API's own
  conventions first and the principles the published guides agree on (`procedures/api-design.md`); the
  compatibility checks run only when the API already has outside callers.
- **`idleflow:review-security`** reviews every `security` task against the repo's own security controls and
  the practice the published guidance agrees on (`procedures/security-review.md`): each finding traces where
  outside data enters and where it is used, is rated with the OWASP Risk Rating and carries its CWE id, and
  only what the diff introduced counts.
- **`/idleflow:blueprint <part>`** saves a reusable part of a project, a feature or mechanism worth having again,
  as ideas with no code and no stack (**`idleflow:blueprinter`**, `templates/blueprint.md`): its flows, rules,
  states, edge cases, what it keeps, outside services by role, lessons and plain-language test cases.
  `run.sh blueprint-check` lists every line with code, a file name or an identifier, and fails until none is left. It is kept in
  `~/.idleflow/blueprints/` for any project, and in `docs/blueprints/` on a yes. `/idleflow:feature <blueprint>`
  builds it in another project, its test cases as the acceptance. The retro and `/idleflow:endsession` suggest
  one when a run or a session built something worth keeping.
- **`/idleflow:unslopify`** audits any project's UI for what makes it read as AI-generated, against a cited
  catalogue (`procedures/slop.md`; the research is `docs/research/ui-slop.md`). `scripts/slop-scan.sh` finds the
  patterns in the source, `scripts/slop-page.js` measures them in the rendered page, and the
  **`idleflow:slop-auditor`** judges the rest from screenshots. A pattern the project's design system or a recorded
  waiver chose is reported as chosen and never fixed; pages are scored on how many patterns occur together, not on
  any single one, and a palette is only a note. The verdict on each page, made by people, mixed or generated, is a
  judgement of craft (choices that follow from the page's own subject) calibrated against researched human-made
  sites (`docs/research/human-made.md`), never of taste. The human picks report, polish, restyle or redesign; the fix runs as an idleflow run with the
  project's own tokens, and the fixed pages are checked again so one generic look is not traded for another.
- **`idleflow:review-ux`** uses the app the way its end users would, journey by journey, at phone and desktop
  widths, asking at each step whether an end user would know what to do, find it, connect it with their goal and
  see that it worked (`procedures/ux-review.md`). Each place an end user gets stuck, confused or misled is a
  finding with a screenshot, the step, the cause and the smallest change that removes it. It runs after the
  design reviewer on `ui` tasks when the repo has an approved preview (`STEP_UX`), after the merge when the app
  runs only from the main checkout, and on its own as `/idleflow:ux`, which can fix the findings through a run
  and walk the journeys again.
- **`/idleflow:api-docs`** writes a project's API and service reference from its code in one step
  (**`idleflow:api-docs`**): every element callers use, its inputs, outputs, errors and authentication, and an
  example run against the service where one is served, in the repo's own docs format. A source list beside each
  docs file records the files each element depends on; `run.sh api-docs check` lists the elements whose source changed since their docs were
  written, every run checks a task's changes with it before review, and `/idleflow:api-docs check` reports
  drift at any time.

## What it adds over plain Claude Code

| Plain Claude Code | With idleflow |
|---|---|
| One session plans, codes and checks its own work | Sonnet explores, Fable plans, two Opus critics attack large or risky plans, implementers build, two independent reviewers gate each task |
| One working tree; parallel work collides | One git worktree per task; a hook blocks edits outside the files a task owns |
| Size of a change is unchecked | A diff gate sends oversized tasks to an auditor that accepts, splits or rejects |
| Each session starts fresh | Lessons from every run feed the next plan; conventions and settings are committed for the team |
| Status lives in people's heads | Milestones as checkboxes in `progress.md`, `/idleflow:progress`, session handoffs, docs grounded against the code |
| Settings differ from human to human | `/idleflow:customize` per repo, shared through git; `/idleflow:doctor` checks setup and updates |

## Decisions baked in (and where to change them)

| Decision | Value | Where |
|---|---|---|
| Plan context | Sonnet explores, Fable plans from `context.md` | `agents/explorer.md`, `agents/planner.md` |
| Debate | asymmetric roles, hard cap 2 rounds; the human picks which cuts and contested points to accept, the planner adjudicates the rest | `agents/red-team.md`, `agents/cost-critic.md`, `DEBATE_ROUNDS` |
| Sizing | Haiku reports size, risk and new dependency; size sets implementers and reviewers, risk (or size L) the debate, a new dependency the stack and library research; an S overrun adds the conformance reviewer | `agents/classifier.md`, `SIZE_*` in conf |
| Fan-out | ≤4 implementers, partitioned by file globs, Sonnet default / Opus when plan says | `MAX_IMPLEMENTERS`, `model:` per task in plan |
| Diff gate | 1500 code lines per task (+300 slack); `.md`, `.txt`, lockfiles, generated excluded | `DIFF_LIMIT`, `DIFF_SLACK`, `DIFF_EXCLUDE` |
| Retry | one per task, on Opus, then stop and ask; a reject whose findings need only a reworded message, a report fix or a small edit takes a cheaper round instead (up to two per task), and a widened ownership map is never a retry | `MAX_RETRIES`, steps 5 and 7 of `commands/feature.md` |
| Findings on approved tasks | counted in `review_findings`, and listed in the run's final message so the human can fix them or file a follow-up | reviewers, `run.sh findings` |
| Tests | `tests_first: true` forced wherever entry points have no tests | planner §3, conformance reviewer §4 |
| Mutation sweep | implementers break their own change on purpose; a fault no test catches needs a test or a reason | `STEP_MUTATION`, plan `mutation:`, implementer, correctness reviewer |
| Design | designer before planning and a design reviewer on `ui` tasks; a lasting design system per repo | `STEP_DESIGN`, `STEP_DESIGN_OPTIONS`, `agents/designer.md`, `agents/review-design.md`, `procedures/design.md` |
| API review | an API reviewer on `api` tasks: the API's own conventions first, compatibility only once it has callers | plan `api:`, `agents/review-api.md`, `procedures/api-design.md` |
| Security review | a security reviewer on `security` tasks: the repo's own controls first, a traced source and use for every finding, OWASP risk rating with CWE ids | plan `security:`, `agents/review-security.md`, `procedures/security-review.md` |
| AI-looking UI | `/idleflow:unslopify`: a cited catalogue, static and rendered checks, chosen looks kept, pages scored on combinations of patterns, fixes at the level the human picks and checked again | `procedures/slop.md`, `agents/slop-auditor.md`, `scripts/slop-scan.sh`, `scripts/slop-page.js` |
| UX review | a reviewer walks the app's journeys as an end user on `ui` tasks with a preview, and on its own; each place an end user gets stuck is a finding with its screenshot | `STEP_UX`, `agents/review-ux.md`, `procedures/ux-review.md`, `commands/ux.md` |
| API docs | written from the code by one step, each element's source recorded; a task that changes a source updates its docs before review | `api_docs:` in conventions, `agents/api-docs.md`, `commands/api-docs.md`, `run.sh api-docs` |
| Blueprints | a reusable part saved as ideas with no code, in `~/.idleflow/blueprints/` and the repo on a yes; built from as an issue; suggested by the retro when worth keeping | `agents/blueprinter.md`, `commands/blueprint.md`, `templates/blueprint.md`, `run.sh blueprint-check` |
| Placeholders | code that cannot do its job yet fails loudly; a plausible default is a blocking finding | implementer, correctness reviewer |
| Checkable findings | each review finding says whether a deterministic check would have caught it; repeats become a lesson | reviewers, `agents/retro.md` |
| Known base failures | a failure already on the commit a task started from is shown there with `run.sh exec --base`, never argued; the gate's baseline and every task's proven ones go into the run's `known-failures.md`, which later implementers and the correctness reviewer get, with or without a gate | step 5 of `commands/feature.md`, `agents/implementer.md` |
| Unverified checks | a check that cannot decide for a cause outside the task is listed, never passed and never retried; an environment cause asks the human, a CI job still owed goes into the run's reports | `agents/review-correct.md`, `agents/review-design.md`, plan `verify: ci <job name>`, `commands/feature.md` §5 and §7 |
| CI evidence | a task that needs what only a CI job shows (`blocked_until: ci <job>`) waits for it; a `verify: ci <job>` criterion is shown failing on the task's test alone (`ci_red:`) and passing on its head, and the reviewers get both logs. Once the human agrees, the run pushes the commit to `idleflow/<run id>/ci`, never the default branch, reads the job with `gh`, and deletes the branch at `finish` | `CI_EVIDENCE_MINUTES`, `CI_EVIDENCE_TRIES`, `run.sh ci`, steps 5 and 6 of `commands/feature.md` |
| Lessons | per repo, `.idleflow/lessons.md` or `docs/lessons.md` (`lessons_in:`), ≤1 per run | `agents/retro.md`, `run.sh path lessons` |
| Metrics | `.idleflow/runs/log.jsonl` per run; the time log (estimate against actual lines, minutes and reported tokens per task, with why) feeds the planner's estimates | `scripts/run.sh finish`, `time_log`, `agents/retro.md` |
| Priority | quality > tokens > time | retry on Opus; `opus` allowed per task; critics on Opus |
| Readability mode | asked once per repo; `repo` on existing code and `balanced` on an empty repo when nobody answers | `.idleflow/conventions.md`, `commands/style.md` |
| Ignore rules | idleflow's own paths go to `.git/info/exclude` or `.gitignore`, asked once; exclude until answered | `ignore_in:` in conventions.md, `run.sh ignore` |
| Stack / library research | greenfield or a new dependency; ≥3 sources per candidate, URL on every claim | `agents/stack-advisor.md`, `agents/stack-researcher.md`, `agents/library-scout.md` |
| Large repo | ≥ 100 000 hand-written code lines → code-map proposal | `LARGE_REPO_LOC`, `run.sh loc` |
| Attribution, releases, meta commentary | asked by `/idleflow:init`, recorded in `CLAUDE.md` | `templates/CLAUDE.md`, `agents/review-conform.md` §7 |
| Market research | `/idleflow:init` only; verdict viable / viable-if / crowded / weak | `agents/market-researcher.md` |
| Tooling | skills from Idle-Sync/skills, marketplace plugins, workflows; installed only when accepted by name | `agents/tooling-advisor.md`, "Tooling" in conventions.md |
| Pushback | once, with evidence, then the human's call stands | `templates/CLAUDE.md`, planner, both orchestrators |
| Release | `unreleased`: no compatibility work for end users or callers who do not exist yet, a change replaces the old thing outright; `live` (and unset): every rule that protects them applies; the doctor suggests `live` once a release tag appears | `release:` and `kept_data:` in conventions.md, planner, red team, conformance reviewer, `procedures/api-design.md` |
| While waiting | `work`: while CI, the gate, a long job or an agent runs, the run goes on with what does not depend on its result; `wait`: it waits; a missing line waits | `while_waiting:` in conventions.md, `commands/feature.md` |
| Code map | on a large repo, the stack advisor proposes code maps, semantic search with a local model among them; an accepted one is searched first by every agent that searches the repo, its hits confirmed by grep or a read | `code_map`, `code_map_query`, `code_map_status` in conventions.md, `LARGE_REPO_LOC`, `agents/stack-advisor.md` |
| UI preview of a task's own work | each task gets three ports (`IDLEFLOW_PORT`, `IDLEFLOW_PORT_API`, `IDLEFLOW_PORT_DB`) and a database name (`IDLEFLOW_DB`), so `preview:` can start the worktree's whole stack; without a worktree preview, browser criteria wait for the check after merge | `preview:` in conventions.md, `run.sh preview`, planner §2 |
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
- **A run that stopped.** `/idleflow:feature resume <run id>` goes on with a run that stopped before it
  finished (a `needs-human` stop, a time limit): its merged tasks stay merged, the rest are built from its
  locked plan on the branch as it is now, without exploring, planning or debating again.
- **A stale base.** `/idleflow:feature` checks `run.sh behind` first and offers to pull, so a run plans with
  the team's latest lessons and settings.
- **Who did what.** `run.json` records `by`; merge commits carry the run id; `/idleflow:progress` shows the
  whole team's landed work from git history, plus the milestones in `progress.md`.
- **Teammates without idleflow.** `run.sh team-install` adds idleflow to the committed `.claude/settings.json`
  (`extraKnownMarketplaces` and `enabledPlugins`); Claude Code loads it for each teammate once they trust
  the folder. The doctor warns when more than one human commits and it is not set.

## Docs kept by code

Anything a doc says that the repo itself can answer is written by code, not by an agent or by hand.
Blocks between `<!-- idleflow:generated NAME -->` and `<!-- idleflow:end -->` are regenerated by
`run.sh docs` and checked by `run.sh docs --check` (exit 1 when stale) in the files `generated_docs:`
in conventions names; unset, that is every tracked Markdown file with a block plus the index, the
progress file and `CLAUDE.md`, also when the repo keeps them out of git:

| Block | Written from |
|---|---|
| `files` | `git ls-files`: one row per top-level folder and file; descriptions people write are kept, new rows say `(describe)` |
| `commands` | `package.json` scripts (with the repo's package manager), Makefile and justfile targets, pyproject console scripts |
| `milestones` | ticked against total boxes per milestone in the progress file |
| `dependencies` | `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `go.mod` |
| `runs` | idleflow merge commits in git history: who, when, how many tasks |
| `settings` | this repo's conventions and idleflow settings |

Every generator reads only committed files and git history, so every clone writes the same text. A run
regenerates after its last merge and commits only what changed; the retro then only replaces `(describe)`
with a line read from the code. The doctor warns about a stale block or an undescribed entry, and suggests
adding blocks to an index that has none; setup adds them after a yes.

## Fitting a repo that has its own rules

Conventions "Repo fit" and "Records" let idleflow work inside a repo's existing process instead of
beside it. Every key is optional and missing keys keep the defaults, so older repos change nothing.

| Key | What it does |
|---|---|
| `worktrees_in: inside` | Task worktrees in `.idleflow/worktrees/` (ignored) instead of a sibling folder |
| `worktree_setup: <command>` | Run in each new worktree before the implementer starts (`$MAIN`, `$WORKTREE` set). Runs only as committed and after each human approves that exact text (`run.sh approve`, local git config); fails loudly; may not change tracked files |
| `progress_file`, `index_file`, `vocabulary_file`, `sessions_dir`, `time_log`, `lessons_in: <path>` | Use the records the repo already keeps |
| `index_rewrite: no` | The retro leaves the index to the repo's own process |
| `session_names: per-person` | Notes in a folder per human, `<github-login>/s_0001.md`, each numbered on its own, so a team never collides (`git config idleflow.person <name>` names the folder) |
| `session_names: numbered` | Keep a repo's `s_0001.md` numbering (two writers can collide) |
| `gate: <command>` | The repo's own check is the definition of done: run on the base first (old failures are not blamed on the run), by implementers and the correctness reviewer, and after merge. Same approval rule as `worktree_setup` |
| `services: <command>` | A quick check that the services the tests need are up (`pg_isready -t 3 -p 5433`): run before the baseline and before each group's build, review and the gate after merge, so a database that is down stops the run with a question, not as a failed test. Same approval rule as `gate` |
| `services_start: <command>` | Starts those services (`docker compose up -d db`) when the check fails and the human says **Start them**: run once from the main checkout, then the check again for up to `SERVICES_START_SECONDS`. The run never stops what it started, and says so at the end. Same approval rule as `gate` |
| `gate_runs: once` + `gate_quick: <command>` | For a slow gate (over `SLOW_GATE_SECONDS`, 120 by default): a quick check per task and the full gate once after merge, the base checked only if it fails. `repo-gate` times every run; `detect` suggests this and points out commit or push hooks that run the tests every time (idleflow never edits hooks) |
| `commit_format: conventional` | Task and merge commits as Conventional Commits (subject at most 72 characters, ids in the body) |
| `commit_format: plain` | Task and merge commits as plain sentences with no prefix (merges `Merge <task title>`, ids in the body) |
| `shared_files: <paths>` | Files every task may add its own lines to (a changelog, an index the repo's checks need a row in), merged by union |

`/idleflow:setup` finds what a repo already has with `run.sh detect` (the share of Conventional Commits
subjects, existing lessons, progress and numbered session files, an Unreleased changelog section, an
index idleflow did not write, a rule against writing outside the folder, check scripts and make, just
or npm targets) and asks about each setting the evidence points to; `/idleflow:doctor` lists the same
suggestions until they are answered. A repo already on idleflow changes nothing until someone says yes.

## Customizing one project

Every number in `config/idleflow.conf` is a default. `/idleflow:customize` overrides it for one repo in
`.idleflow/idleflow.conf`, turns a step on or off (`STEP_DEBATE`, `STEP_STACK`, `STEP_LIBRARIES`,
`STEP_TOOLING`, `STEP_DOC_KEEPER`, `STEP_MUTATION`, `STEP_DESIGN`, `STEP_DESIGN_OPTIONS`, `STEP_UX`), sets an agent's model (`MODEL_<AGENT>`), adds instructions to an
agent (`.idleflow/agents/<agent>.md`), or replaces an agent's prompt (`.claude/agents/idleflow-<agent>.md`,
with a base copy so `/idleflow:doctor` can merge later plugin updates into it). A replaced agent keeps the
built-in output contract. Everything is committed, so the team shares it. The project file is parsed, never
sourced: a key outside the list in `scripts/conf.sh`, or a value out of range, is skipped and reported.

Each customization can be reported as a comment on one issue per setting on Idle-Sync/idleflow
(`customization: DIFF_LIMIT`, `customization: prompt planner`, ...). The first time, the project answers
report / always / never; `always` and `never` are saved per human in the clone's git config
(`idleflow.reportCustomizations`), never committed, so one teammate's answer never posts from another's account. Instruction text and
prompt diffs are shown before every post.

## Layout

```
.claude-plugin/plugin.json      manifest
.claude-plugin/marketplace.json lets the repo itself be added as a marketplace
commands/feature.md             the orchestrator — the run procedure lives here
procedures/design.md            idleflow's design handbook; design-data.md beside it holds the reference values
procedures/api-design.md        the API reviewer's principles; the cited research is docs/research/api-dx.md
procedures/security-review.md   the security reviewer's rules; the cited research is docs/research/security-review.md
procedures/slop.md              the UI slop catalogue, scoring and fix rules; the cited research is docs/research/ui-slop.md
procedures/ux-review.md         how the UX reviewer walks journeys: the four questions per step, the paths beyond the expected one, severities
procedures/talking.md           how every command talks to the human: plain language, language, tone and explanation settings
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
commands/blueprint.md           save a reusable part as a code-free blueprint, to build again later in any project
commands/unslopify.md           audit a UI for what reads as AI-generated, then fix it at the level the human picks
commands/ux.md                  use the app as its end users would, report where they get stuck, fix on a yes and walk again
commands/api-docs.md            write the API and service reference from the code; `check` reports docs that no longer match
skills/vocab/SKILL.md           one term per concept: check, fix, backfill and add a term; /idleflow:vocab, used inside and outside a run
agents/                         one file per role; frontmatter sets the model
hooks/hooks.json                PreToolUse → ownership-guard
scripts/run.sh                  run lifecycle: new / wt / own / get / set / inc / report / keep / gate / merge / snapshot / finish / loc /
                                conf, plus path / migrate / doctor / update-check / detect / repo-gate / commands / approve /
                                reword / findings / session-name / behind / team-install / custom / agent / vocab / ui (`bash scripts/run.sh` lists them)
scripts/diff-gate.sh            counts hand-written code lines vs base, emits JSON verdict
scripts/ownership-guard.sh      the hook; blocks edits outside a task's globs
scripts/rt.sh                   picks Python or Node, whichever is installed
scripts/conf.sh                 loads config/idleflow.conf, then a project's .idleflow/idleflow.conf (parsed, never run)
scripts/idleflow.py             the JSON / gate / guard logic (Python)
scripts/idleflow.js             the same program in Node; keep the two in sync
scripts/selftest.sh             end-to-end check of the scripts in a throwaway repo
scripts/slop-scan.sh            the static tier of /idleflow:unslopify: catalogue patterns found in UI source
scripts/slop-page.js            the rendered tier: one expression a browser tool evaluates in the page; returns measures and flags
scripts/shellcheck-new.sh       fails only on shellcheck findings a change adds over a base commit
.github/workflows/checks.yml    CI: selftest on both runtimes, plugin validate, new shellcheck findings
config/idleflow.conf            every number the workflow uses
templates/                      plan.md, context.md, lessons.md, conventions.md, prd.md, progress.md, install-note.md,
                                index.md, session.md, time-log.md, CLAUDE.md, vocabulary.md, design-system.md, blueprint.md
setup.md                        global install, written for Claude Code to execute
PUBLISHING.md                   validate, push to GitHub, install elsewhere, release updates
ISSUES.md                       how every idleflow issue is written: kinds, title, four headings; the form and plugin-feedback use it
.github/ISSUE_TEMPLATE/         the GitHub issue forms (bug, workflow, idea, pushback), built from ISSUES.md
vocabulary.md                   one term per concept in idleflow's own Markdown; `run.sh vocab --all` checks it, in the selftest
```

## Runtime

The bash scripts run on bash 3.2 or newer (macOS ships 3.2 as `/bin/bash`; CI runs the selftest on it) and need either **Python ≥ 3.8** or **Node ≥ 18** on `PATH`; `scripts/rt.sh` tries
`python3`, then `python`, then `node`, and `IDLEFLOW_RUNTIME=node` (or `python`, or a full path)
pins one. `bash scripts/run.sh conf` prints which one is in use. On Windows, bash comes from Git for
Windows; paths in every form (`D:\x`, `D:/x`, `/d/x`) are normalised before comparison.

```
bash scripts/selftest.sh                      # exercises every script against a scratch repo
IDLEFLOW_RUNTIME=node   bash scripts/selftest.sh
IDLEFLOW_RUNTIME=python bash scripts/selftest.sh
bash scripts/shellcheck-new.sh origin/main    # shellcheck findings this branch adds
```

`.github/workflows/checks.yml` runs the selftest on each runtime, under the newest bash and under bash 3.2, `claude plugin validate --strict`
on `.`, `agents` and `commands`, and `shellcheck-new.sh` against the base on every pull request to
`main` and every push to it, and the first two nightly on `main`.

## Per-repo state

```
.idleflow/lessons.md                 commit this
.idleflow/conventions.md             commit this: style rules, readability mode, stack decisions
prd.md  progress.md  index.md      repo root, when docs are on; humans and the retro both edit them
vocabulary.md                      repo root, when docs are on; one term per concept, kept by humans
docs/design-system.md              a repo with a UI only (.idleflow/ without docs); the designer keeps it
CLAUDE.md                          the idleflow block: start-of-session doc grounding, end-of-session notes
docs/research/<capability>.md      library and stack research with sources
docs/sessions/s_<time>-<author>.md one note per run or session, named so teammates never collide; ignored or committed, asked once
.idleflow/runs/active/               the run in progress (a plain directory; renamed to <id>/ on finish)
.idleflow/runs/active/gaps.md        plugin_gap lines agents append; asked about before every finish
.idleflow/runs/<id>/                 ignored (.git/info/exclude or .gitignore, asked once); issue, context, plan, debate/, tasks/, review/, run.json
.idleflow/runs/log.jsonl             one line per finished run — tokens aren't captured yet, but
                                   size, retries, fix rounds, gate trips and review findings are
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
- In ownership globs `*` and `?` are the only wildcards and both cross `/`; every other character is literal, so `src/pages/[slug].astro` names that file. `src/**` is the usual shape. The guard hook, both reviewers (through `run.sh unowned`) and the plan check (`run.sh plan-check`) use the same matcher. Diff-gate excludes use git pathspec globs and are all `**/`-prefixed so they match at any depth.
- `model: fable` in agent frontmatter depends on account access; setup.md step 3 checks and falls back.
- The orchestrator is a prompt, not code. It will occasionally drift. The "Rules you never break" block at the bottom of `commands/feature.md` is the first thing to tighten when it does.
