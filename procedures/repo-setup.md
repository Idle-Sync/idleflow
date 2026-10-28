# Repo setup procedure

Shared by `commands/feature.md` and `commands/init.md`. Each section states when it applies; the caller runs the ones that apply, in order R1 → R6, then returns to its own steps. `RUN` is `"${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"` (always quoted; the path may contain spaces). Agent names are the ones the plugin exposes: `idleflow:<name>`.

Pushback applies throughout: when the human's answer conflicts with something you can cite (a research file, the code, the tests, a documented platform limit), say so once before acting, with the evidence and a better option with its cost; then do what they decide and record the decision and its reason. Nothing without evidence.

## R1. Readability mode and ignore file — when `.idleflow/conventions.md` is missing, or its `mode:` or `ignore_in:` is `unset` or absent

Ensure `.idleflow/conventions.md` exists (copy `templates/conventions.md` if not; if it has no `ignore_in:` line, add the template's "Ignore rules" section). Ask the unanswered questions in one AskUserQuestion call.

**Readability mode.** When the repo already has code (`bash "$RUN" loc` is above 0), offer this first:

- **Match this repo (Recommended)** — write code the way the surrounding code is already written: implementers copy the naming, comment style and density, guard shape, call style and test structure of the files next to the change. Pros: changes read like the rest of the codebase. Cons: carries the repo's habits forward, the bad ones too. Show the style being chosen in the option's `preview`: 8–15 lines quoted exactly from one representative source file (the largest non-test, non-generated file in `git ls-files` of the main language), its `path:line` on the first line.

Then these three in this order; on a repo with no code yet Balanced is first and marked Recommended:

- **Balanced** — an idiom only when it reads as one plain sentence; otherwise explicit. Pros: short where short is clear, explicit where it is not. Cons: the line is a judgement call, so the reviewer will sometimes disagree with the implementer.
- **Explicit** — loops, named intermediate values, one step per line; no comprehensions, chaining or one-liners. Pros: anyone can follow it, easy to step through in a debugger. Cons: more lines per feature; experienced readers will find it long.
- **Idiomatic** — the language's native idioms wherever they fit (comprehensions, built-ins, chaining). Pros: shorter, what fluent readers expect. Cons: denser; a nested idiom hides what happens, and newcomers slow down.

Write the answer into the `mode:` line (`repo`, `balanced`, `explicit` or `idiomatic`). If the human is not present, write `repo` when the repo has code and `balanced` otherwise, and say so. `/idleflow:style` changes it later.

**Ignore file.** Where idleflow writes its own ignore rules (`.idleflow/runs/`, a local `docs/`):

- **Local only: .git/info/exclude (Recommended)** — the rules live in this clone; nothing about idleflow appears in the committed `.gitignore`. Cons: another clone starts without them, and its first run adds them there.
- **Shared: .gitignore** — the rules are committed and apply to every clone. Cons: everyone who reads the repo sees idleflow's paths.

Write `exclude` or `gitignore` into the `ignore_in:` line, then run `bash "$RUN" ignore .idleflow/runs/` so the entry is in the chosen file (`run.sh new` put it in `.git/info/exclude` before the question was asked; that copy is harmless). An entry already in a committed `.gitignore` stays until the human removes it. If the human is not present, write `exclude` and say so.

## R2. Project docs

When `docs:` in `.idleflow/conventions.md` is `unset`: set it to `yes` when the run is greenfield, or when `prd.md` or `progress.md` exists at the repo root, or when `CLAUDE.md` contains `<!-- idleflow start -->`; otherwise set `docs: no`. When `docs: no`, skip the rest of R2.

When `docs: yes` (a caller may name only some of these sub-steps):

1. Copy any of `templates/prd.md`, `templates/progress.md`, `templates/index.md` whose target does not exist at the repo root. Create `docs/research/` and `docs/sessions/`; copy `templates/session.md` to `docs/sessions/TEMPLATE.md` if missing.
2. `CLAUDE.md`: if absent, copy `templates/CLAUDE.md`. If present without the `<!-- idleflow start -->` marker, append the template's block. Never overwrite a human's content. Fill the "Commands" lines from `context.md` §5 when known; leave `co_author_claude:` and `releases:` as they are unless R2 is running from `/idleflow:init`, which fills them.
3. If `docs_in_git:` is `unset`, ask once: **Keep docs/ in the repo (Recommended)** — research, market research and session notes are shared with everyone who clones; cons: more files in review. **Keep docs/ local** — notes stay on this machine; cons: the next person starts without the research or the session history. Write the answer. On `no`, run `bash "$RUN" ignore docs/` (it writes to the file `ignore_in:` names). If the human is not present, choose `yes` and say so.
4. If `lessons_in:` is `unset` and `docs_in_git: yes`, ask once: **.idleflow/lessons.md (Recommended)** — next to the conventions every agent already reads; cons: a dot-folder people rarely open. **docs/lessons.md** — next to the research and session notes the team reads; cons: one more file in `docs/`. Write `idleflow` or `docs`. On `docs`, move an existing file with `git mv .idleflow/lessons.md docs/lessons.md`. With `docs_in_git: no`, write `idleflow` without asking: lessons are shared, and a local `docs/` would hide them. If the human is not present, write `idleflow`.

Who writes these later: the planner fills `prd.md` on a greenfield run; the retro writes the session note and updates `progress.md` and `index.md` after every run; the doc-keeper grounds all of them before every run. No task may own them.

## R3. Stack conventions — when nothing is under "Stack decisions" yet, on a greenfield run or when the classifier reports `new_dependency: true`

1. `LOC=$(bash "$RUN" loc)`. Spawn `idleflow:stack-advisor` in mode `scan` with: repo root, `greenfield`, the conventions path, `LARGE_REPO_LOC` from `bash "$RUN" conf`, `LOC`, and the project description path (`context.md`, or `brainstorm.md` from init). It writes `.idleflow/runs/active/stack-scan.md` and replies with a JSON line. If `gaps` is 0, tell the human `Stack: already current.` and continue to R4.
2. Split the scan reply's `research_units` into chunks of at most 5, in order. With one chunk, spawn `idleflow:stack-researcher` with the chunk, the scan path and output path `.idleflow/runs/active/stack-research.md`, and wait. With more than one, spawn it once per chunk with that chunk, the scan path and output path `.idleflow/runs/active/stack-research-<n>.md` (`<n>` counts from 1), wait for each, then `cat` them in order into `.idleflow/runs/active/stack-research.md` before step 3. It checks several internet sources per unit and cites every claim. Add up the units and unverified counts of the replies and tell the human `Stack research: <N> units, <K> unverified`.
3. Spawn `idleflow:stack-advisor` in mode `propose` with the scan, research and conventions paths. It writes `.idleflow/runs/active/stack.md`.
4. Read `stack.md`. Ask once with AskUserQuestion, `multiSelect: true`, one option per proposal: label = title, description = `proposal` + one pro + one con + `needs_install`. Defaults first. If the human is not present, take the defaults and say so.
5. Append one line per accepted proposal under "Stack decisions": `- [<ID>] <title>: <proposal>  (why: <one pro>; evidence: <one URL>)`. Declined: `- [<ID>] declined: <title>`.
6. Copy `stack-research.md` to `docs/research/stack-<YYYY-MM-DD>.md` when `docs: yes`.

On a greenfield run the advisor must include a **Quality tooling** proposal per language (formatter, linter, type checker, test runner, pre-commit hook); its agent file carries the per-language table.

Tell the human: `Stack: <N> accepted, <M> declined.` An accepted proposal that changes the repo (a `pyproject.toml`, a `Dockerfile`, a code-map tool) becomes a task in the plan; nothing is installed into the repo here.

## R4. Libraries before code — when greenfield, or when the classifier reports `new_dependency: true`

Spawn `idleflow:library-scout` with: the issue path (or `brainstorm.md`), `context.md` path (or `brainstorm.md`), the conventions path, `docs/research/` (create it; research lives there even when `docs: no`), and output path `.idleflow/runs/active/libraries.md`. It names the generic capabilities the change needs, checks what the repo already depends on, researches established libraries across several sources with a URL on every claim, and writes one `docs/research/<capability>.md` per capability. Wait.

Read `libraries.md`. If every capability is `reused` or there are none, tell the human `Libraries: nothing new needed.` and continue. Otherwise ask once with AskUserQuestion (at most four questions per call; a second call if needed), one question per capability: options = each library (label = name; description = one pro, one con, install present/absent) plus **Write it by hand** with the scout's line-and-upkeep cost. Write every answer under "Stack decisions" as `- [<ID>] <capability>: <library> (<why>; research: docs/research/<file>)` or `- [<ID>] <capability>: hand-written (<why>)`, and set `status: decided: <choice>` at the top of the research file. If the human is not present, choose the option with the most recent maintained release and say so.

Tell the human: `Libraries: <N> chosen, <M> hand-written, <K> reused.`

## R5. Tooling — when nothing is under "Tooling" yet and the run is greenfield or size L

Spawn `idleflow:tooling-advisor` with the project description path, the conventions path, and output paths `.idleflow/runs/active/tooling.md` and `docs/research/tooling.md`. It inventories installed plugins and skills, checks the Idle-Sync/skills catalogue against what is installed, and proposes the skills, marketplace plugins and workflows this project will use often, plus the skills that do not exist yet. Wait.

Read `tooling.md`. Ask once with AskUserQuestion, `multiSelect: true`, one option per proposal (label = name and kind; description = job, one con, the exact install command or "installed"). Defaults first.

For each accepted item, show the `install:` command and run it exactly as quoted. These commands change only the user's Claude Code setup (`claude plugin install …`, a skill folder under `~/.claude/skills/`), never the repo; that is why this is allowed while installing into the repo is not. If a command fails, show the error and move on. When anything was installed, `bash "$RUN" set tooling_installed <N>` (the session handoff names the restart) and tell the human that agents in this session cannot use it until Claude Code restarts, and that a restart (not `/reload-plugins` mid-run) is the safe way to pick it up. Append accepted items under "Tooling" in conventions: `- <name> (<kind>): <job>`. List any "Skills that do not exist yet" and say each can be requested with `/idleflow:skills-feedback "<line>"`; do not open issues unasked.

Tell the human: `Tooling: <N> installed, <M> declined, <K> skills to request.`

## R6. Snapshot — always, after R1–R5 and before any worktree is created

`bash "$RUN" snapshot` commits `.idleflow/` (everything in it but `runs/`, which is ignored), `CLAUDE.md`, `prd.md`, `progress.md`, `index.md`, `README.md`, `.gitignore`, `.gitattributes` and `docs/` if any changed. Worktrees branch from HEAD, so without this step implementers would not see the conventions they are told to read. A path the repo ignores (`.gitignore` or `.git/info/exclude`) is skipped with one stderr line and never committed: a `docs/` the human chose to keep local in R2 stays local, no exceptions. If the skipped path is `.idleflow/` or the lessons file (someone ignored them), tell the human in one line, because the implementers then cannot read them.
