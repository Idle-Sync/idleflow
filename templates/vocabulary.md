# Vocabulary

One term per concept in this repo's docs. Agents and people find things by exact text (grep,
search and replace), so a concept with two names is one that a search half misses. Each row names
the term to use, what it means here, and the other spellings never to write for it. Write those
spellings in backticks: the check skips code, so this file never flags itself.

`run.sh vocab` (idleflow's run script) checks every Markdown file a run changes against this
table. It matches whole words, ignores case, and skips code.

The first rows are idleflow's own terms that show up in this repo's docs (session notes,
`progress.md`, the index). Under them, add a row for each term of this project's that has more
than one spelling in use. A word inside a term to use is that term, so one row can use a phrase
such as `end user` while another bans `user`. A line that has to quote a banned word ends with
`<!-- vocab: allow -->`.

| use | means | never write |
|---|---|---|
| main checkout | the repo's own working tree, outside the task worktrees | `main repo`, `main repository` |
| worktree | the git worktree a task is built in, apart from the main checkout | `work tree` |
| run folder | a run's folder, `.idleflow/runs/active/` or `.idleflow/runs/<run id>/` | `run directory`, `run dir` |
| base sha | the commit a task's worktree starts from | `base commit` |
