<!-- idleflow install start -->
## idleflow

This repo is set up for idleflow (the `.idleflow/` folder). When `/idleflow:feature` is not among
the commands available in a session here, tell the human once, before other work:

> This repo uses idleflow, so changes follow the team's plan, review and handoff flow. Install it
> with `claude plugin marketplace add Idle-Sync/idleflow && claude plugin install idleflow@idlesync`,
> then restart Claude Code. Trusting this folder may already have installed it: check `/plugin`.

What it adds over plain Claude Code:

- A written plan before any code, attacked by a red team and a cost critic on large or risky changes.
- Parallel implementers in separate git worktrees, each limited by a hook to the files it owns.
- Two independent reviewers (correctness, conformance) and a diff-size gate on every task.
- Lessons from every run feed the next plan; conventions and settings are shared through git.
- Milestones, progress, session handoffs and project docs kept current for the whole team.

Without it, still read `.idleflow/conventions.md` and the lessons file it names before changing
code: they are the team's rules.
<!-- idleflow install end -->
