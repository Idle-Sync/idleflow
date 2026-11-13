# Reaching research sources

Read by `idleflow:market-researcher`, `idleflow:stack-researcher` and `idleflow:library-scout`. Many
sites refuse a plain page fetch (GitHub, review sites, Reddit, some news sites answer 403), so reach a
source through its machine endpoint first, with Bash and `curl -s` or `gh`, and fall back to the
page only after that. Cite the page a person can open (the release page, the thread, the package
page) and add `via <endpoint>` when the fact came from the endpoint.

## Routes, first choice first

| Fact | Route |
|---|---|
| Latest release, its date | `gh api repos/<owner>/<repo>/releases?per_page=5` (a monorepo publishes one release per package: pick the package's), then `gh api repos/<owner>/<repo>/tags?per_page=5` |
| Last commit, licence, stars, open issues | `gh api repos/<owner>/<repo>` (`pushed_at`, `license.spdx_id`, `stargazers_count`, `open_issues_count`) |
| Issues people open (complaints, bugs) | `gh search issues --repo <owner>/<repo> --sort reactions --limit 20 <words>`, or `gh api 'search/issues?q=repo:<owner>/<repo>+<words>&sort=reactions'` |
| npm version, licence, repository | `curl -s https://registry.npmjs.org/<pkg>/latest` |
| npm downloads | `curl -s https://api.npmjs.org/downloads/point/last-month/<pkg>` |
| PyPI version, licence, project links | `curl -s https://pypi.org/pypi/<pkg>/json` |
| crates.io version and downloads | `curl -s https://crates.io/api/v1/crates/<crate>` |
| Go module version | `curl -s https://proxy.golang.org/<module>/@latest` |
| Developer discussion, first-hand | Hacker News: `curl -s 'https://hn.algolia.com/api/v1/search?query=<words>&tags=story'` (comments: `tags=comment`); Stack Overflow: `curl -s 'https://api.stackexchange.com/2.3/search/advanced?order=desc&sort=votes&q=<words>&site=stackoverflow'` |
| Buyer reviews (G2, Capterra, Trustpilot, app stores), Reddit | WebSearch for the quoted complaint, then WebFetch on the result; when that is refused and a browser tool is available in this session (a `mcp__*browser*`, `mcp__playwright__*` or `mcp__claude-in-chrome__*` tool), open the page with it; otherwise the source is unreachable |
| Official docs, install commands | WebFetch on the docs page; for a repository README, `gh api repos/<owner>/<repo>/readme -H 'Accept: application/vnd.github.raw'` |

Send a plain `User-Agent` with `curl` (`-A "research-client/1.0"`); never one that names the person or
the project.

## When a source cannot be reached

Do not retry the same URL. Write it in your output under `unreachable:` with the status (`403`,
`timeout`) and what you used instead. A fact that only the unreachable source had stays out, or is
marked `unverified`. Evidence from the vendor itself (its blog, its landing page, a post it wrote
about a competitor) is never first-hand: label it `vendor-sourced`, and say in the summary how many
of the sources behind a conclusion are first-hand.
