---
description: "Same pipeline as /idleflow:feature, biased for bug fixes — classifier leans S, explorer looks for the failing path and the regression test first. Usage: /idleflow:fix <bug description, issue URL, or failing test name>"
argument-hint: "<bug description or URL>"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

Run the full procedure in `${CLAUDE_PLUGIN_ROOT}/commands/feature.md` (read it now and follow it step by step) with these three differences:

1. **Explorer prompt** adds: "This is a bug. In §1 state the reproduction (a command or test that currently fails, or how to make one). In §2 the `source:` and `sibling:` lines are required. In §4 note whether a test already covers the broken path — if not, the plan must add a regression test before the fix."

2. **Classifier prompt** adds: "This is a bug fix. Size it from the expected hand-written lines and files of the fix plus its regression test; a fix that touches several modules is not bigger for that reason. Most fixes are `risk: low` and `new_dependency: false`; set either only for a reason in your rules."

3. **Plan must include a regression test.** When you read plan.md after step 3, check that at least one acceptance criterion is a test that reproduces the reported failure end to end (the path the user took, not only the function that changed) and fails on the current code, and, when §2 lists a `sibling:` other than `none` and a task's `cause:` is `source`, that another criterion tests at least one sibling the same fix covers. If either is missing, send the plan back to the planner once with the missing instruction before proceeding.

Everything else — worktrees, gate, review, retry limits, merge, retro — is identical. A fix that turns out to be an L is still allowed; the pipeline handles it.

Bug: $ARGUMENTS
