---
description: Request a skill from the IdleSync skills catalogue (github.com/Idle-Sync/skills). Drafts an issue describing the job the skill should do, shows it, and opens it with gh after you confirm. Usage: /idleflow:skills-feedback <what you need the skill to do>
argument-hint: <what you need the skill to do>
allowed-tools: Bash, Read, Glob, Edit, AskUserQuestion
---

How you talk to the human (plain language, `language:` and `tone:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

Need: $ARGUMENTS

1. `gh auth status` must succeed. If `gh` is missing or logged out, say so, print the issue draft from step 3 so it can be pasted at https://github.com/Idle-Sync/skills/issues/new, and stop.
2. Check it does not already exist: `gh api repos/Idle-Sync/skills/contents --jq '.[] | select(.type=="dir") | .name'` and `gh issue list --repo Idle-Sync/skills --search "<three key words from the need>" --state all --limit 10`. If a skill or an open issue already covers the need, say which and stop; offer to add a comment with this project's example instead (`gh issue comment`), only if the human says yes.
3. Draft the issue. Title: `Skill request: <the job in six words>`. Body:

```
## Job
<the need, one paragraph, as the human stated it, cleaned up>

## When it comes up
<how often, and in which step of the work; from prd.md / progress.md / context.md if they exist, else from the need>

## Example tasks
- <a concrete task the skill would handle, 1 to 3 of them>

## Project context
- Stack: <from .idleflow/conventions.md "Stack decisions", or "not recorded">
- Tools in use: <from docs/research/tooling.md "Already have", or "not recorded">

## What exists today
<what the tooling advisor or the human found that almost fits, and why it does not>
```

No meta commentary: no "the user asked", "while running idleflow". No secrets, no private paths, no customer names.

4. Show the draft and ask with AskUserQuestion: **Open the issue** / **Edit first** (free text, apply, show again) / **Cancel**.
5. `gh issue create --repo Idle-Sync/skills --title "<title>" --body-file <tmpfile>`. Then `gh issue edit <url> --add-label skill-request` and ignore the error if the label does not exist.
6. Reply with one line: the issue URL, or `cancelled`. If `docs/research/tooling.md` exists, append `- requested: <title> — <url>` under "Skills that do not exist yet".
