---
description: "Write a project's API and service reference from its code in one step: every element callers use, its inputs, outputs, errors and authentication, and an example checked against the running service, in the repo's own docs format. Later runs that change the API update the docs in the same task, and `/idleflow:api-docs check` reports docs that no longer match the code. Usage: /idleflow:api-docs [check | the part of the API to document]"
argument-hint: "[check | the part of the API to document]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

How you talk to the human (plain language, `language:`, `tone:` and `explain:` from conventions): `${CLAUDE_PLUGIN_ROOT}/procedures/talking.md`; read it now.

You set up and run the docs step; `idleflow:api-docs` writes the docs. Spawn it as `commands/feature.md` **Spawning an agent** says (`bash "$RUN" agent api-docs` first).

```bash
RUN="${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"     # keep the quotes: the path may contain spaces
```

## 1. Where the docs live

When `.idleflow/conventions.md` is missing, run R1 of `${CLAUDE_PLUGIN_ROOT}/procedures/repo-setup.md` first. Then read `api_docs:` under "Repo fit".

When it is `unset` or missing, find what the repo already has among its tracked files: a machine-readable contract for its API, and a folder of reference docs. Ask once where the reference lives: **Use <what was found>** for each find (first when there is one), **A new `docs/api/` folder**, and the human's own path typed in. Write the answer as `api_docs: <folder>` under "Repo fit" (for a contract file, the folder that holds it). When it is `none`, the repo has decided to go without: say so and stop.

## 2. Check, or write

**`check`** as the argument: `bash "$RUN" api-docs check`.
- Exit 0: tell the human the docs match the code as recorded, and stop.
- Exit 1: show each line in plain words: the element, the source that changed, the docs file. Ask **Update them** / **Leave them**. On update, go on to step 3 with those lines as `Stale:`.
- Exit 2: show its message. When the folder has no source lists yet, offer to write the docs (step 3).

**Anything else** is the scope to document, and no argument is the whole API.

## 3. The docs

1. **The service, for the examples.** `bash "$RUN" new --audit api-docs` (it parks a run left active and says so: repeat that line; it refuses while one of that run's jobs or previews still runs: show its message and stop). `bash "$RUN" commands`; when `preview` is listed and unapproved, ask as `commands/feature.md` **Repo commands** says. With an approved preview, `bash "$RUN" preview main start` and keep the address. Without one, ask once: **Give the address of the service running on this machine** (the human starts it) / **Write the examples from the code** (they are marked as not run). Take only an `http` or `https` address on `localhost`, `127.0.0.1` or `[::1]`; ask again for any other, and never pass one on.
2. **Spawn `idleflow:api-docs`** with: the repo root, the `api_docs:` folder, the format (the contract or docs set found in step 1, or `none`), the scope, `${CLAUDE_PLUGIN_ROOT}/procedures/api-design.md`, the address (or `Service: none (<reason>)`), and `Stale: <the check's lines>` when step 2 sent them.
3. `bash "$RUN" preview main stop` when step 1 started it. `bash "$RUN" api-docs check`: it must exit 0 now; any line it prints goes back to the agent once with `Stale:`, and what is still listed after that is reported.
4. Tell the human what was documented, how many examples ran against the service and how many are written from the code, and each `unclear:` line as a question about the API. Ask **Commit the docs** / **Leave them uncommitted to review first**. On commit, stage the docs folder and `.idleflow/conventions.md` by name and commit `docs: API reference` (`docs: bring the API reference up to date` for an update).
5. `bash "$RUN" finish done`.

## After this

Once `api_docs:` names a folder with its source lists, every `/idleflow:feature` run keeps it true: the planner gives a task that changes a recorded source, or adds an API element, the docs file that covers it; the task's check before review (`commands/feature.md` **API docs check**) lists what it left stale; and the check runs on the main checkout after the last merge.
