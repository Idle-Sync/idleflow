# API design

Read by `idleflow:review-api` before it reviews. An API here is any surface another program or developer calls and cannot change in the same commit: an HTTP, GraphQL or RPC operation, a library's public symbol, a CLI used from scripts, or an event or webhook payload. The principles below are the ones the published guides and the research agree on; the sources, with what each says, are in `docs/research/api-dx.md` in the plugin.

## 1. The API's own conventions come first

The guides disagree on several choices, so applying one guide to another API produces noise. In order:

1. **A written convention wins.** A style file, a linter configuration or a ruleset in the repo is the standard.
2. **Otherwise the unchanged API is the convention.** Derive, for each kind of element the change touches, the pattern the existing API uses most, and note the count behind it.
3. **New and changed elements are judged against that convention.** A mismatch is a finding even when the new element follows a published guide better.
4. **A change that only adds to the API never migrates a convention.** Migrating one is a separate decision, and on an API with outside callers it is itself a breaking change. Record it as an observation at most.
5. **With no convention yet**, recommend the standards-based default and ask that the choice be written down as the API's convention. Where the guides disagree (section 3), present the options and their trade-offs, not one answer.
6. **Conventions that conflict with each other** are flagged, and new code follows the majority.
7. **Some findings hold whatever the house style:** a security weakness, a breaking change on an API with outside callers, and new code that violates a requirement of a protocol the API claims to follow. When the house style itself does the wrong thing throughout, report that as an observation; do not ask the new element alone to differ, since that adds inconsistency.

## 2. What the guides agree on

- **Consistency.** One term per concept, one casing per element type, one shape per kind of thing, across the whole API.
- **Shape.** Names say what a thing is or does, from the caller's side. Operations do what their method or name promises, with no hidden side effects; reads never change state. A custom operation exists only when the standard ones cannot express the action.
- **Errors.** The status or exit code is correct for the failure, the body has a stable machine-readable code and a message that says what went wrong and what the caller can do about it, and every error response uses the API's one error shape. A failure is never reported as success.
- **Lists.** Every operation that returns a collection is paginated from the start, with an opaque cursor or page token, a bounded page size, and a way to know there is more. Filtering and sorting follow one pattern across the API.
- **Compatibility.** Changes add; they do not remove, rename, retype or change the meaning or default of what callers use. A removal is preceded by a deprecation that says what to use instead and when the old thing goes.
- **Retries.** A write a caller may retry is safe to retry: the caller supplies an idempotency key, or the operation is idempotent by design, and the API says which.
- **Authentication and authorisation.** Credentials travel only in the place the scheme defines, never in a URL. Every operation checks that the caller may act on this particular object and see each field it returns.
- **Limits.** Overload is answered with the protocol's rate-limit status and a hint of when to retry; documented limits match the behaviour.
- **Contract and docs.** The API has a machine-readable contract that matches the code, and docs that explain intent, every error a caller can receive, and a working example per operation, checked against the behaviour.
- **Libraries and SDKs.** The public surface is small and hard to misuse: safe defaults, required inputs that cannot be forgotten, types or option structures that can grow without breaking callers, and network or other costly work visible to the caller.
- **Events and webhooks.** Each event has a unique id, a type and a timestamp, is signed so the receiver can verify the sender, may arrive more than once or out of order (the docs say so, and consumers process it idempotently), and has a documented, versioned payload.

## 3. Where the guides disagree

Casing of fields, where a version goes (or whether there is one), the error body format, where pagination links go, naming of booleans, null versus absent fields, which rate-limit headers to send, how strictly to follow REST, the choice of authentication scheme, and thin versus full event payloads. On these the API's own convention decides (section 1); a reviewer never raises them from a guide alone.

## 4. Outside callers

Compatibility rules apply when the API has a caller the change cannot update in the same commit. `release:` in `.idleflow/conventions.md` decides first: `unreleased` means it has none, apart from stored data (below). With `live`, or with no answer, it has one when any of these holds: a release tag or a published package exists, the contract names a production server, a stability marker says beta or stable, other repositories or installed clients call it, data or messages in the API's format are already stored, or a receiver has registered for its events. When none holds, the API has no outside callers yet:

- The compatibility checks in section 2 (removal, rename, retype, changed defaults, deprecation work, breaking-change tools) are skipped.
- Every other check still applies.
- The choices that are free now and breaking later are pushed hardest: every principle of section 2 that cannot be adopted after release without breaking callers, and each convention section 1 needs, chosen once and written down.

Stored data counts as an outside caller even before release: a wire format already written to disk or a queue keeps its compatibility rules.

## 5. Checks a tool makes, and checks that need judgement

**A tool or a short script**, when the stack has one; its output is the finding's evidence:
- Contract linters for the API's contract format, with the repo's own ruleset when it has one.
- Breaking-change diffs of the contract or the public surface against the base, only when the API has outside callers.
- Short scripts over the diff, one for each principle of section 2 whose breach can be decided from the text: a value that departs from the API's majority pattern, an element section 2 requires that is absent, and a contract that disagrees with the code.

**Judgement**, citing the principle:
- Whether names are clear and consistent in meaning, not only in form.
- Whether the resource and operation model fits the domain, and a custom operation is warranted.
- Whether error messages let the caller act.
- Whether the docs explain intent, failures and guarantees.
- Whether the design makes callers do avoidable work or round trips.
- Authorisation per object and per field.
- A change of behaviour, not only of shape, on an API with outside callers.
- Library ergonomics: misuse resistance, defaults, and visible costs.

Rules that experiments found to change how well developers understand an API weigh more than rules with no evidence behind them; `docs/research/api-dx.md` names them.
