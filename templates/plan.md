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

### T1: <title>
group: 1                      # tasks in the same group run in parallel; groups run in order
depends_on: []                # task ids
model: sonnet | opus
tests_first: true | false     # true when context.md §4 shows no tests for the entry points
mutation: true | false        # the implementer proves the tests catch deliberate faults (see STEP_MUTATION)
ui: true | false              # touches what a person sees; gets the design spec and the design reviewer
estimate_lines: <N>           # hand-written code lines, added+deleted
estimate_minutes: <N>         # from the time log's rows for similar tasks; say so in notes when there are none
owns:                         # globs; no overlap with other tasks in the same group
  - src/path/**
  - tests/path/**
entry_points:
  - src/path/file.py: <function/class>
acceptance:
  - A1: <observable behaviour>  → verify: <command or test name>
  - A2: ...
notes: <anything the implementer must know that context.md doesn't say; max 5 lines>

### T2: ...

## Merge order
<T0 → T1, T2 (parallel) → T3. State it even if obvious.>

## Verification after merge
<The one command that runs the suite / smoke test. Required.>

## Open questions for the human
<Only things the plan cannot resolve. Empty is fine.>

## Debate resolution (filled in on revision)
- R1: accepted — <what changed> | rejected — <why> | deferred to human — <question>; a point the human decided ends with "(human decision)"
- C1: ...
