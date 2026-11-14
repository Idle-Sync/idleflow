# Context: <issue title>

## 1. Issue restated
<What is broken or wanted. What "done" observably means.>

## 2. Entry points

<!-- for a bug, first: source: <file>:<function> — <how it produces the bad state>, then one sibling: <file>:<function> — <the case> line each, or sibling: none -->
- `path/to/file.py` — <what it does> — `func_a`, `ClassB.method`
- ...

## 3. Blast radius (one hop)
- `path/to/caller.py` — imports `func_a`; <one line>
- ...

## 4. Existing tests
- `path/to/file.py` → `tests/test_file.py::test_x`, `tests/test_file.py::test_y`
- `path/to/other.py` → none
- Other tests using what changes: `tests/test_report.py` — builds a fake `Order`; `tests/fixtures/orders.py` — constructs `Order` | none

## 5. Conventions observed
- Errors: <style> (see `path:line`)
- Naming: <style> (see `path`)
- Config: lives in <where> (see `path`)
- Migrations: <how> (see `path`)
- Tests: runner `<cmd>`; single test: `<cmd>`
- Test shared state: <what the suite shares beyond one process (a database, a lock file, a fixed port)>, reset with `<cmd>` (see `path`) | none
- Install: `<frozen-lockfile command, through corepack when the package manager is pinned>` (see `path`) | none

## 6. Prior art
- `<commit or path>` — <a similar change; what to copy>

## 7. Risks (facts only)
- <fragile thing, with path>
- Lessons that apply: "<quoted line from the lessons file>" | none

## 8. Open questions
- <what the code could not answer>
