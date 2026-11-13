# Reaching research sources

Read by `idleflow:market-researcher`, `idleflow:stack-researcher` and `idleflow:library-scout`. Many
sites refuse a plain page fetch (GitHub, review sites, Reddit, some news sites answer 403), so reach a
source through its machine endpoint first, with Bash and `curl -s` or `gh`, and fall back to the
page only after that. Cite the page a person can open (the release page, the thread, the package
page) and add `via <endpoint>` when the fact came from the endpoint.

## Routes, first choice first

| Fact | Route |
|---|---|
| Latest release, its date | GitHub API `repos/<owner>/<repo>/releases?per_page=5` (a monorepo publishes one release per package: pick the package's), then `repos/<owner>/<repo>/tags?per_page=5` |
| Last commit, licence, stars, open issues | GitHub API `repos/<owner>/<repo>` (`pushed_at`, `license.spdx_id`, `stargazers_count`, `open_issues_count`) |
| Issues people open (complaints, bugs) | GitHub API `search/issues?q=repo:<owner>/<repo>+<words>&sort=reactions` |
| npm version, licence, repository | `curl -s https://registry.npmjs.org/<pkg>/latest` |
| npm downloads | `curl -s https://api.npmjs.org/downloads/point/last-month/<pkg>` |
| PyPI version, licence, project links | `curl -s https://pypi.org/pypi/<pkg>/json` |
| crates.io version and downloads | `curl -s https://crates.io/api/v1/crates/<crate>` |
| Go module version | `curl -s https://proxy.golang.org/<module>/@latest` |
| Developer discussion, first-hand | Hacker News: `curl -s 'https://hn.algolia.com/api/v1/search?query=<words>&tags=story'` (comments: `tags=comment`); Stack Overflow: `curl -s 'https://api.stackexchange.com/2.3/search/advanced?order=desc&sort=votes&q=<words>&site=stackoverflow'` |
| Buyer reviews (G2, Capterra, Trustpilot, app stores), Reddit | WebSearch for the quoted complaint, then WebFetch on the result; when that is refused and a browser tool is available in this session (a `mcp__*browser*`, `mcp__playwright__*` or `mcp__claude-in-chrome__*` tool), open the page with it; otherwise the source is unreachable |
| Official docs, install commands | WebFetch on the docs page; for a repository README, GitHub API `repos/<owner>/<repo>/readme` with the header `Accept: application/vnd.github.raw` |

A "GitHub API `<path>`" route is GitHub's public REST API, which needs no login: call it with
`gh api '<path>'` when `gh auth status` succeeds, and otherwise with
`curl -s -A "research-client/1.0" 'https://api.github.com/<path>'` (add `-H '<header>'` where the row
names one). Without a login GitHub allows 60 requests an hour and 10 searches a minute, so ask only
for what the claim needs; a `403` with `rate limit exceeded` goes under `unreachable:` like any other.

Send a plain `User-Agent` with `curl` (`-A "research-client/1.0"`); never one that names the person or
the project.

## When a source cannot be reached

Do not retry the same URL. Write it in your output under `unreachable:` with the status (`403`,
`timeout`) and what you used instead. A fact that only the unreachable source had stays out, or is
marked `unverified`. Evidence from the vendor itself (its blog, its landing page, a post it wrote
about a competitor) is never first-hand: label it `vendor-sourced`, and say in the summary how many
of the sources behind a conclusion are first-hand.
