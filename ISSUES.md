# Writing an idleflow issue

Every issue on Idle-Sync/idleflow follows this one blueprint, whoever writes it: a person on the
GitHub form, `/idleflow:plugin-feedback`, the `plugin_gap:` lines a run files at its end, or a
maintainer filing a follow-up from a review. One shape makes issues easy to triage, easy to find
duplicates of, and easy to fix at the cause.

## Before you write

1. **Search first.** `gh issue list --repo Idle-Sync/idleflow --search "<three key words>" --state all`.
   If one already covers it, add your case as a comment there instead of opening a new issue.
2. **One problem per issue.** Two unrelated problems are two issues. Several symptoms of one cause
   are one issue: list them all under "What happened".
3. **Nothing private.** No secrets, tokens, private paths, or code and plan contents from your
   project. Run evidence (sizes, counts, verdicts, config values) is fine.

## Kinds

| Kind | Use it when |
|---|---|
| `bug` | idleflow did the wrong thing: a step, script or agent behaved differently from what its own docs say |
| `workflow` | a rule or step is missing or wrong: idleflow did what it says, and what it says is the problem |
| `idea` | something new idleflow does not do at all |
| `pushback` | idleflow and the human disagreed, and one of them was right; say which and why |
| `customization` | written only by `/idleflow:customize`; see the end of this file |

When unsure between `bug` and `workflow`: if the docs promise the behaviour, it is a `bug`.

## Title

`<kind>: <what is wrong, in about six words>`

Name the problem, not the fix. `bug: diff gate counts generated lockfiles` is right;
`bug: add lockfiles to the ignore list` is a fix pretending to be a problem.

## Body

Use these four headings, in this order, every time. Leave a section out only when it truly does not
apply, and never rename it.

```
## What happened / what is wanted
<one paragraph: what you saw, or what you want. For a bug, the command you ran and what it did.>

## Expected
<what should have happened, or what the idea changes. When you know where it goes wrong (which
procedure, agent, script or template writes the bad state), say so: fixes in idleflow go to the
cause, not to the place where the symptom shows up.>

## Evidence
- idleflow <version>, runtime <python or node>, OS <Linux, macOS or Windows>
- run <id>: size <S/M/L>, retries N, gate trips N, review findings N, reviews: <verdicts>
- config: <only the values that matter to this report>
- <links to the PR, commit or file lines involved, when there are any>

## Repro or example
<the shortest command sequence or prompt that shows it. For an idea, a concrete example of it in use.>
```

`/idleflow:plugin-feedback` fills the Evidence section for you from the last run. On the GitHub form,
the version is in the installed plugin's `.claude-plugin/plugin.json`, and `bash scripts/run.sh conf`
in the plugin folder shows the runtime and config.

## Labels

Leave labels to the maintainers; issues are labelled after they are opened. The kind in the title
decides the type label.

## Customization reports

`/idleflow:customize` keeps one issue per setting, titled `customization: <KEY>`,
`customization: model <agent>`, `customization: instructions <agent>` or
`customization: prompt <agent>`, and adds each project's change as a comment on it. Those issues
follow the format in `commands/customize.md`, not the four headings above. Do not open them by hand.
