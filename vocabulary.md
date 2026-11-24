# Vocabulary

One term per concept in idleflow's prompts, commands, procedures, templates and docs. Agents and
people find things by exact text (grep, search and replace), so a concept with two names is a
concept half of whose places a search misses. `bash scripts/run.sh vocab --all` lists every word
below that idleflow's Markdown should never use, and the selftest runs it.

A hit is a "never write" word in any case, as a whole word, outside fenced and inline code. A word
inside one of the terms to use, or inside its plural with an "s" (the "user" in "end user" or
"end users"), is that term. A line that quotes a banned phrase, such as a rule that bans it, ends
with `<!-- vocab: allow -->`.

| use | means | never write |
|---|---|---|
| human | the person who runs idleflow, answers its questions and approves what it does | user, users, person, persons |
| end user | someone who uses the product a repo builds | |
| OS user | an account on the machine, as file permissions and `$USER` mean it | |
| main checkout | the repo's own working tree, outside the task worktrees | main repo, main repository |
| run folder | a run's folder, `.idleflow/runs/active/` or `.idleflow/runs/<run id>/` | run directory, run dir |
| base sha | the commit a task's worktree starts from, recorded by `wt add` | base commit |
