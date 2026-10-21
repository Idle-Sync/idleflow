# Publishing idleflow

The repo layout is the single-plugin-at-root case: `.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` sit together, and the marketplace entry uses `source: "./"`.
Nothing needs restructuring to publish.

## 1. Validate locally

```
cd idleflow
claude plugin validate --strict .
```

On this layout (marketplace and plugin in one folder) that call validates `marketplace.json` and the
plugin manifest; point it at the component folders too, since agent and command frontmatter are
only checked that way:

```
claude plugin validate --strict agents
claude plugin validate --strict commands
```

It never runs the scripts, so also run `bash scripts/selftest.sh` on both runtimes
(`IDLEFLOW_RUNTIME=node`, `IDLEFLOW_RUNTIME=python`) and a full local install loop before pushing:

```
claude plugin marketplace add ./
claude plugin install idleflow@idlesync
claude plugin list                # idleflow should show as enabled
```

Then run `/idleflow:fix` on a small bug in a real repo once. If it works locally it will work from GitHub.

## 2. Push to GitHub

```
git init && git add . && git commit -m "idleflow <version>"
gh repo create Idle-Sync/idleflow --public --source . --push
git tag v<version> && git push --tags   # the version in plugin.json
```

A private repo works too; users then need read access to install.

## 3. Install on any machine

```
claude plugin marketplace add Idle-Sync/idleflow
claude plugin install idleflow@idlesync
```

One step on recent versions (shell ≥ 2.1.292, in-session ≥ 2.1.275):

```
claude plugin install idleflow --marketplace Idle-Sync/idleflow
```

In a session: `/plugin marketplace add Idle-Sync/idleflow` → `/plugin install idleflow@idlesync` → `/reload-plugins`.

## 4. Releasing an update

Users stay on the `version` in `plugin.json` until it changes. Pushing new commits without a bump
reports "already at the latest version" on their side. So every release is:

1. Bump `version` in **both** `.claude-plugin/plugin.json` and the plugin entry in `marketplace.json`.
2. Commit, tag (`v0.2.0`), push with tags.

Users update with:

```
claude plugin marketplace update idlesync
claude plugin update idleflow@idlesync
```

Auto-update is off by default for third-party marketplaces; users can turn it on under
`/plugin` → Marketplaces. To pin, add the marketplace with a ref: `Idle-Sync/idleflow#v0.1.0`.
(Per-plugin `ref`/`sha` only applies to `github`/`url`/`git-subdir` sources, not `./`, so pinning
is at the marketplace level for this layout.)

Uninstall: `claude plugin uninstall idleflow@idlesync`; `claude plugin marketplace remove idlesync`.

## 5. Public listings (optional)

- **Anthropic directory** — submit at https://claude.ai/directory/manage ("Submit new" → "Plugin
  bundle"). Needs a paid plan, GitHub connected on claude.ai, and the repo public by go-live (private
  is fine during review). Each version is reviewed; a root-level plugin needs no subpath. Run
  `claude plugin validate .` first.
- **Community marketplace** — `anthropics/claude-plugins-community` (installs as `@claude-community`).
  Submission steps are in its create-plugins guide.
- **`claude-plugins-official`** — curated, invitation via an Anthropic partner contact; no open submissions.

## Notes

- `${CLAUDE_PLUGIN_ROOT}` is substituted inline in command/agent/skill Markdown when Claude Code
  loads it, which is how `commands/feature.md` finds `scripts/run.sh`. It is **not** an environment
  variable inside Bash commands. This is why `setup.md` Option B (manual copy) rewrites it with `sed`.
- Don't write state under the plugin root; it changes on update. Per-repo state lives in
  `.claude/runs/` and `.claude/lessons.md`, which is the right place.
- Keep `name` identical in `plugin.json` and the marketplace entry, or installs by name fail.

Sources: https://code.claude.com/docs/en/plugins/publish.md ·
https://code.claude.com/docs/en/plugins/cli-reference.md ·
https://code.claude.com/docs/en/plugins/manifest-reference.md ·
https://code.claude.com/docs/en/plugins/marketplace-reference ·
https://www.claude.com/docs/plugins/submit
