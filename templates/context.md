# Context: <issue title>

## 1. Issue restated
<What is broken or wanted. What "done" observably means.>

## 2. Entry points
- `path/to/file.py` — <what it does> — `func_a`, `ClassB.method`
- ...

## 3. Blast radius (one hop)
- `path/to/caller.py` — imports `func_a`; <one line>
- ...

## 4. Existing tests
- `path/to/file.py` → `tests/test_file.py::test_x`, `tests/test_file.py::test_y`
- `path/to/other.py` → none

## 5. Conventions observed
- Errors: <style> (see `path:line`)
- Naming: <style> (see `path`)
- Config: lives in <where> (see `path`)
- Migrations: <how> (see `path`)
- Tests: runner `<cmd>`; single test: `<cmd>`
- Install: `<frozen-lockfile command, through corepack when the package manager is pinned>` (see `path`) | none

## 6. Prior art
- `<commit or path>` — <a similar change; what to copy>

## 7. Risks (facts only)
- <fragile thing, with path>
- Lessons that apply: "<quoted line from .claude/lessons.md>" | none

## 8. Open questions
- <what the code could not answer>
