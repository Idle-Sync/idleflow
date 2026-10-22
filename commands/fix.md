---
description: Same pipeline as /idleflow:feature, biased for bug fixes — classifier leans S, explorer looks for the failing path and the regression test first. Usage: /idleflow:fix <bug description, issue URL, or failing test name>
argument-hint: <bug description or URL>
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

Run the full procedure in `${CLAUDE_PLUGIN_ROOT}/commands/feature.md` (read it now and follow it step by step) with these three differences:

1. **Explorer prompt** adds: "This is a bug. In §1 state the reproduction (a command or test that currently fails, or how to make one). In §2 lead with the file where the wrong behaviour happens, not where the symptom appears. In §4 note whether a test already covers the broken path — if not, the plan must add a regression test before the fix."

2. **Classifier prompt** adds: "This is a bug fix. Size it from the expected hand-written lines and files of the fix plus its regression test; a fix that touches several modules is not bigger for that reason. Most fixes are `risk: low` and `new_dependency: false`; set either only for a reason in your rules."

3. **Plan must include a regression test.** When you read plan.md after step 3, check that at least one acceptance criterion is a test that fails on the current code and passes after the fix. If it isn't there, send the plan back to the planner once with that single instruction before proceeding.

Everything else — worktrees, gate, review, retry limits, merge, retro — is identical. A fix that turns out to be an L is still allowed; the pipeline handles it.

Bug: $ARGUMENTS
