# Plan: <issue title>

run: <run-id>
size: S | M | L
greenfield: false
issue: <link or one-line reference>

## Goal
<Two sentences: the observable change, and what "done" means.>

## Not doing
<Bullet list of things deliberately out of scope, each with a one-clause reason. The cost critic attacks this section.>

## Stack & style constraints
<Copied from .idleflow/conventions.md so implementers and reviewers see one list: readability mode; every "Stack decisions" line that touches this change, including libraries chosen by the library scout (name + research file) and capabilities the human chose to hand-write. A task may not contradict these.>

## Interfaces (serial, land first — omit if none)
<Shared types, signatures, schema changes every parallel task depends on. This is task T0 if present.>

## Tasks
<One section per task, headed `### T<n>: <title>`. The id names the task's worktree folder and branch, so it is `T` and a number, nothing else.>

### T1: <title: what the task delivers, in a few words; the merge commit's subject uses it, so it does not start with "merge">
group: 1                      # tasks in the same group run in parallel; groups run in order
depends_on: []                # task ids
blocked_until: none           # or: revision — <what it waits to learn, from which task>; its section is final only after that task has run
model: sonnet | opus
tests_first: true | false     # true when context.md §4 shows no tests for the entry points
mutation: true | false        # the implementer proves the tests catch deliberate faults in the code this task changes, in files it owns (see STEP_MUTATION)
ui: true | false              # touches what a person sees; gets the design spec and the design reviewer
estimate_lines: <N>           # hand-written code lines, added+deleted
estimate_minutes: <N>         # from the time log's rows for similar tasks; say so in notes when there are none
owns:                         # globs; no overlap with other tasks in the same group
  - src/path/**
  - tests/path/**
entry_points:
  - src/path/file.py: <function/class>
acceptance:
  - A1: <observable behaviour>  → verify: <command or test name | ci <job name>, only for what needs a service the run cannot start>
  - A2: ...
notes: <anything the implementer must know that context.md doesn't say; max 5 lines>

### T2: ...

## Merge order
<T0 → T1, T2 (parallel) → T3. State it even if obvious.>

## Verification after merge
<The one command that runs the suite / smoke test. Required.>

## Open questions for the human
<Only things the plan cannot resolve. Empty is fine. One line each, numbered, with what the plan assumes until answered:>
- Q1: <question> (default: <the answer the plan is written for>)

## Debate resolution (filled in on revision)
- R1: accepted — <what changed> | rejected — <why> | deferred to human — <question>; a point the human decided ends with "(human decision)"
- C1: ...
