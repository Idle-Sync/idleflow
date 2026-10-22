# idleflow — global setup

This file is written for Claude Code to execute. Open a Claude Code session anywhere (the home directory is fine) and say:

> Read setup.md in this folder and set idleflow up globally for me. Ask before anything destructive.

Claude: follow the steps in order. Each step says what to run, what success looks like, and what to do if it doesn't. Stop and ask the human at any `ASK:` line. Do not skip the verification steps; a half-installed hook is worse than none.

---

## Step 1 — Check prerequisites

Run:
```
claude --version
git --version
python3 --version 2>/dev/null || python --version 2>/dev/null || node --version
gh --version 2>/dev/null || echo "gh not installed (optional; needed only for /idleflow:feature <github-url>)"
```
Need: Claude Code present, git ≥ 2.20 (worktrees), and **one of** Python ≥ 3.8 or Node ≥ 18. The scripts pick whichever exists (`IDLEFLOW_RUNTIME=node|python` pins it). On Windows, bash comes from Git for Windows and must be on `PATH`. If `claude` is missing, stop; this plugin runs inside Claude Code.

Also confirm the plugin files are intact:
```
ls .claude-plugin/plugin.json commands/*.md agents/*.md procedures/*.md hooks/hooks.json scripts/*.sh scripts/idleflow.py scripts/idleflow.js config/idleflow.conf templates/*.md
chmod +x scripts/*.sh
bash scripts/selftest.sh        # must end with PASS; it also prints which runtime was picked
```
If `selftest.sh` stops with "no runtime", install Python or Node and retry.

## Step 2 — Choose where it lives

ASK: "Install as a plugin from a local marketplace (recommended — survives updates, one place to edit), or copy agents/commands into ~/.claude (simpler, but hooks must be merged by hand)?"

### Option A — plugin via local marketplace (recommended)

Move this folder somewhere permanent, e.g. `~/.claude/plugins-src/idleflow`, then:
```
mkdir -p ~/.claude/plugins-src
mv "$(pwd)" ~/.claude/plugins-src/idleflow     # skip if already there
cd ~/.claude/plugins-src/idleflow
claude plugin marketplace add ./
claude plugin install idleflow@idlesync
claude plugin list
```
Success looks like `idleflow` in the list as enabled. If the `claude plugin` subcommands have a different shape in this version, run `claude plugin --help` and map: *add a marketplace from a local path* → *install the plugin named idleflow from it*. If marketplace-from-path is not supported, fall back to running Claude Code with `claude --plugin-dir ~/.claude/plugins-src/idleflow` for now and tell the human they can alias it.

When the human later pushes this to `github.com/Idle-Sync/idleflow`, the same two commands work with the repo slug instead of `./`, which is how they'd install it on a second machine.

### Option B — copy into ~/.claude

```
mkdir -p ~/.claude/agents ~/.claude/commands/idleflow ~/.claude/idleflow
cp agents/*.md ~/.claude/agents/
cp commands/*.md ~/.claude/commands/idleflow/
cp -r scripts config templates commands agents procedures ~/.claude/idleflow/
```
(`commands`, `agents` and `procedures` are copied under `~/.claude/idleflow/` too because the command files read each other and the procedure file by path.)
Then the commands reference `${CLAUDE_PLUGIN_ROOT}`, which only exists for plugins. Replace it:
```
sed -i 's#\${CLAUDE_PLUGIN_ROOT}#'"$HOME"'/.claude/idleflow#g' ~/.claude/commands/idleflow/*.md ~/.claude/idleflow/commands/*.md ~/.claude/idleflow/procedures/*.md
```
And merge the hook into `~/.claude/settings.json` (read it first; preserve existing hooks):
```json
"hooks": {
  "PreToolUse": [
    { "matcher": "Edit|Write|MultiEdit|NotebookEdit",
      "hooks": [ { "type": "command", "command": "bash ~/.claude/idleflow/scripts/ownership-guard.sh", "timeout": 10 } ] }
  ]
}
```
In this layout the commands are namespaced by the directory; check `/help` for the exact names (`/idleflow:feature` on current versions). Agents are plain `explorer`, `planner`, … without the `idleflow:` prefix, so when a command prompt says `idleflow:planner`, use `planner`.

## Step 3 — Verify the model names resolve

The agents use `model: fable`, `opus`, `sonnet`, `haiku` in their frontmatter. Check that `fable` is accepted on this account:
```
claude --model fable -p "reply with the single word ok" 2>&1 | tail -3
```
If this errors with an unknown-model message: edit `agents/planner.md` and change `model: fable` to `model: opus`, and tell the human: "Fable isn't available as a subagent model here; the planner runs on Opus. To keep Fable planning, run the orchestrator session itself with `claude --model fable` and the planner will inherit it only if you also remove the `model:` line from planner.md." ASK which they prefer.

## Step 4 — Verify the hook fires

Make a scratch repo and simulate a run:
```
d=$(mktemp -d) && cd "$d" && git init -q && echo hi > a.txt && git add . && git -c user.name=t -c user.email=t@t commit -qm init
RUN="<plugin root>/scripts/run.sh"
bash "$RUN" new hook-test
bash "$RUN" wt add T1         # prints the worktree path
bash "$RUN" own T1 '["src/**"]'
```
Now, from inside Claude Code with the plugin enabled, try to Write a file at `<the worktree path>/other.txt`. Success: the write is **blocked** with a `[idleflow] BLOCKED` message. Then try `<worktree>/src/ok.txt`: it should succeed. Finally:
```
bash "$RUN" gate T1          # should print JSON with "verdict":"ok"
bash "$RUN" wt rm T1
bash "$RUN" finish test
cd ~ && rm -rf "$d" "${d}__wt"
```
If the write was *not* blocked: the hook isn't registered. Run `/hooks` inside Claude Code to see what's loaded, and check that `hooks/hooks.json` is referenced by `plugin.json` (Option A) or merged into settings.json (Option B).

## Step 5 — Per-repo first run

In a real repo, nothing needs pre-creating; `/idleflow:feature` creates `.claude/runs/` (and ignores it in `.git/info/exclude`, or in `.gitignore` when conventions say `ignore_in: gitignore`), copies `templates/lessons.md` and `templates/conventions.md` into `.claude/`, and commits them itself (`run.sh snapshot`, with the human's git identity). Both files are what make the workflow improve; keep them committed.

Recommend to the human, in one line each:
- Run the orchestrator session on Opus (`claude --model opus`); it's the longest-lived context in the run and doesn't need Fable. Only the planner subagent uses Fable.
- Start with `/idleflow:fix` on a real but small bug to see the S path end to end before running an L feature.
- After ~10 runs, read `.claude/runs/config-proposals.md` in each repo and apply the numbers that make sense to `config/idleflow.conf`.

## Step 6 — Report

Tell the human: where the plugin lives, which option was used, whether Fable resolved, that the hook test passed, and the two command names. Nothing else.
