---
description: Report a bug, a bad decision, or an idea about idleflow itself to github.com/Idle-Sync/idleflow. Collects the run's evidence (run id, config, gate and review results), shows the draft, and opens the issue with gh after you confirm. Usage: /idleflow:plugin-feedback <what went wrong or what you want>
argument-hint: <what went wrong or what you want>
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

Feedback: $ARGUMENTS

**Batch mode.** The orchestrator reads this file at the end of a run and follows it with a list of `plugin_gap:` lines the human already agreed to report. Then: step 1 applies once; step 2 runs per line but only skips duplicates, it asks nothing; each line becomes its own issue of kind `workflow` (or `idea`), evidence = the run id and the agent named in the line; step 4 is replaced by showing all drafts together once, with one AskUserQuestion: **Open all** / **Cancel** (no per-issue questions); step 5 runs per issue; step 6 lists every URL.

1. `gh auth status` must succeed. If `gh` is missing or logged out, say so, print the draft from step 3 so it can be pasted at https://github.com/Idle-Sync/idleflow/issues/new, and stop.
2. Check for duplicates: `gh issue list --repo Idle-Sync/idleflow --search "<three key words>" --state all --limit 10`. If one matches, say which and offer to comment there instead (only if the human says yes).
3. Gather evidence, read-only, from this repo if present: the plugin version (`cat "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"`), `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" conf` (config values and runtime), the last line of `.claude/runs/log.jsonl`, and for the most recent run directory under `.claude/runs/` its `run.json` size, retries, gate_trips and review_findings and the one-line `verdict:` of each `review/*.md`. Nothing from `plan.md`, `context.md` or the code: those may be private.

   Decide the kind: `bug` (a step did the wrong thing), `workflow` (a rule or step is wrong or missing), `idea` (something new), `pushback` (idleflow disagreed with the human and the human was right, or the other way round).

   Draft. Title: `<kind>: <six words>`. Body:

```
## What happened / what is wanted
<the feedback, cleaned up, one paragraph>

## Expected
<what should have happened, or what the idea changes>

## Evidence
- idleflow <version>, runtime <from conf>, OS <uname -s or Windows>
- run <id>: size <S/M/L>, retries N, gate trips N, review findings N, reviews: <verdicts>
- config: <only the values that matter to this report>

## Repro or example
<the shortest command sequence or prompt that shows it, when known>
```

No meta commentary, no secrets, no private paths, no code or plan contents from the project.

4. Show the draft and ask with AskUserQuestion: **Open the issue** / **Edit first** (free text, apply, show again) / **Cancel**.
5. `gh issue create --repo Idle-Sync/idleflow --title "<title>" --body-file <tmpfile>`; then `gh issue edit <url> --add-label <kind>` and ignore the error if the label does not exist.
6. Reply with one line: the issue URL, or `cancelled`.
