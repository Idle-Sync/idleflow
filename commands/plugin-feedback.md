---
description: Report a bug, a bad decision, or an idea about idleflow itself to github.com/Idle-Sync/idleflow. Collects the run's evidence (run id, config, gate and review results), shows the draft, and opens the issue with gh after you confirm. Usage: /idleflow:plugin-feedback <what went wrong or what you want>
argument-hint: <what went wrong or what you want>
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

How you talk to the human (plain language, `language:` and `tone:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

Feedback: $ARGUMENTS

**Batch mode.** The orchestrator reads this file at the end of a run and follows it with a list of `plugin_gap:` lines the human already agreed to report. Then: step 1 applies once; step 2 runs per line but only skips duplicates, it asks nothing; each line becomes its own issue of kind `workflow` (or `idea`), evidence = the run id, the agent named in the line, and the run's own `run.json` under `.idleflow/runs/active/` (the run has not finished yet, so `log.jsonl`'s last line is the previous run); step 4 is skipped: the human's yes in the run was the confirmation, so show all drafts together once and open them without asking again; step 5 runs per issue; step 6 lists every URL and every line skipped as a duplicate.

1. `gh auth status` must succeed. If `gh` is missing or logged out, say so, print the draft from step 3 so it can be pasted at https://github.com/Idle-Sync/idleflow/issues/new, and stop.
2. Check for duplicates: `gh issue list --repo Idle-Sync/idleflow --search "<three key words>" --state all --limit 10`. If one matches, say which and offer to comment there instead (only if the human says yes).
3. Gather evidence, read-only, from this repo if present: the plugin version (`cat "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"`), `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" conf` (config values and runtime), the last line of `.idleflow/runs/log.jsonl`, and for the most recent run directory under `.idleflow/runs/` its `run.json` size, retries, gate_trips and review_findings and the one-line `verdict:` of each `review/*.md`. Nothing from `plan.md`, `context.md` or the code: those may be private.

   Draft the issue exactly as `${CLAUDE_PLUGIN_ROOT}/ISSUES.md` describes; read it now. It is the one blueprint for every idleflow issue, the same one people see on the GitHub form: its kinds (`bug`, `workflow`, `idea`, `pushback`), its title (the form its "Title" table gives for the kind: the problem, not the fix, for `bug` and `workflow`) and its four body headings in order. Put the evidence gathered above under its Evidence heading.

No meta commentary, no secrets, no private paths, no code or plan contents from the project.

4. Show the draft and ask with AskUserQuestion: **Open the issue** / **Edit first** (free text, apply, show again) / **Cancel**.
5. `gh issue create --repo Idle-Sync/idleflow --title "<title>" --body-file <tmpfile>`. Add no labels: the maintainers label issues after they are opened (ISSUES.md, Labels).
6. Reply with one line: the issue URL, or `cancelled`.
