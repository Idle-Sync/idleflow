# Time log

How long each idleflow task took against its estimate, and why, one row per task, appended by the
retro after each run. The planner reads the latest rows to estimate the next plan from this repo's
own history. Times come from `run.json` (task start to report, epoch seconds); tokens only when the
harness reported them, otherwise `unknown`. Rows are not rewritten afterwards.

| Date | Run | Task | Model | Lines est / actual | Minutes est / actual | Tokens | Why they differ |
|---|---|---|---|---|---|---|---|
