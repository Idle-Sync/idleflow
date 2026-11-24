# API developer experience: what the published guidance agrees on

Research for idleflow's API reviewer agent. The aim is a reviewer that judges a change against
established, published practice and not against taste. Every claim below links to its source.
Link keys such as `[aip180]` resolve to the URL list at the end of the file.

Sources read: the guidelines of Google (AIPs), Microsoft Azure, Zalando, Heroku, Stripe, GitHub,
AWS and the UK Government Digital Service. The IETF RFCs and drafts on HTTP semantics, problem
details, links, deprecation, sunset, rate limiting and idempotency keys. The GraphQL, Relay,
Protocol Buffers and gRPC docs. The Rust, Go, .NET and Azure SDK library guides. clig.dev for CLIs.
Standard Webhooks, CloudEvents and AsyncAPI for events. The rule sets of the linters Spectral,
Redocly and GraphQL-ESLint, plus the breaking-change tools oasdiff, buf, GraphQL Inspector,
cargo-semver-checks, gorelease and API Extractor. Research papers: Robillard and DeLine (survey and
interviews with Microsoft developers), Myers and Stylos (CACM), Murphy et al. (a comparison of 32
REST guides), Kotstein and Bogner (an expert Delphi study), and Bogner et al. (an experiment with
105 participants). Postman's 2025 State of the API survey. Hacker News threads where developers
complain about APIs.

One limit: Reddit refuses the research fetcher ("domains are not accessible to our user agent"), <!-- vocab: allow -->
so no Reddit thread could be read. The complaints section uses Hacker News, a 2011 developer survey
reported by TechCrunch, and the ACM Queue article "API Practices If You Hate Your Customers".

---

## 1. Summary: where the guides agree and where they disagree

### Strong agreement (stated by four or more independent sources)

1. **Consistency inside one API matters more than any single style choice.** Google says to use
   "the same name or term for the same concept" ([aip190]). Microsoft's .NET guide says
   "inconsistent library design adversely affects developer productivity and discourages adoption"
   ([dotnet]). The Azure SDK guide ranks consistency within a language above consistency with the
   service ([azsdk]). Heroku's guide exists to avoid "design bikeshedding" ([heroku]). Postman's
   2025 survey found 55% of teams struggle with inconsistent documentation and 43% with
   inconsistent definitions ([postman]). Murphy et al. compared 32 published REST guides and found
   they disagree with each other on several topics ([murphy]). The practical consequence: an
   API's own conventions outrank any generic guide.
2. **Do not break existing callers. Add things; do not change or remove them.** Google AIP-180
   ([aip180]), Zalando rule 106 ([zalando]), Azure ([msazure]), Stripe ([stripe-ver]), the Go
   blog's "add, don't change or remove" ([go-compat]), clig.dev's "future-proofing" section
   ([clig]), protobuf's do's and don'ts ([pb-dos]) and GraphQL's versionless schema evolution
   ([gql-schema]) all say this. Hyrum's Law explains why it covers behaviour too: "all observable
   behaviors of your system will be depended on by somebody" ([hyrum]).
3. **Errors use the protocol's status correctly and carry a stable, machine-readable code plus a
   human message. They never leak internals.** RFC 9457 ([rfc9457]), Zalando rules 176, 220 and
   177 ([zalando]), Azure's `x-ms-error-code` ([msazure]), Google's `ErrorInfo.reason` ([aip193]),
   gRPC status codes ([grpc-err]), GDS ([gds]) and Heroku ([heroku]) agree. Bogner et al.'s
   experiment measured it: returning 200 OK for an error significantly hurt comprehension
   ([bogner]). Developers on Hacker News name 200-with-an-error-body as a leading annoyance
   ([hn-hate]).
4. **Every list that can grow is paginated from the start, with an opaque cursor or token.**
   Google says adding pagination later "is a backwards-incompatible change" ([aip158]). Zalando
   rules 159 and 160 ([zalando]), Azure's `nextLink` ([msazure]), GitHub's `Link` header
   ([gh-pag]) and Relay connections ([relay]) agree.
5. **Retried writes must be safe.** The client sends a unique key; the server returns the
   original result for a repeat and rejects a reused key that comes with different parameters.
   Stripe ([stripe-idem]), AWS ([aws-idem]), Google AIP-155 ([aip155]), Azure's
   `Repeatability-Request-ID` ([msazure]), Zalando rules 229 to 231 ([zalando]) and the IETF
   `Idempotency-Key` draft ([idem-draft]) agree. HTTP itself defines PUT, DELETE and the safe
   methods as idempotent ([rfc9110]).
6. **A machine-readable contract (OpenAPI, GraphQL SDL, .proto, AsyncAPI) is written and
   published.** Zalando rules 100, 101 and 192 ([zalando]), GDS ([gds]), Heroku's "provide
   machine-readable JSON schema" ([heroku]) and AsyncAPI for event APIs ([asyncapi]).
7. **Documentation with working examples is where APIs most often fail.** Robillard and DeLine
   surveyed and interviewed over 440 Microsoft developers. They found the most severe learning
   obstacles were in documentation: missing intent, missing code examples, no mapping from usage
   scenarios to API elements, poor penetrability, and poor format ([robillard]). Postman's 2025
   survey ([postman]), the Rust checklist's C-EXAMPLE rule ([rust]), Heroku's "provide executable
   examples" ([heroku]) and Hacker News complaints about "absolutely no example code" ([hn-hate])
   point the same way.
8. **Deprecate before removing: say so in the contract and at runtime, and give a date.** RFC
   9745's `Deprecation` header ([rfc9745]), RFC 8594's `Sunset` header ([rfc8594]), Zalando rules
   187 to 191 ([zalando]), GraphQL-ESLint's `require-deprecation-reason` and
   `require-deprecation-date` rules ([gql-eslint]), Google's 180-day beta deprecation period
   ([aip185]) and GDS ([gds]).
9. **Webhooks are signed, carry a unique event ID, are retried with backoff, are not guaranteed
   in order, and must be processed idempotently.** Standard Webhooks ([stdwh]), Stripe
   ([stripe-wh]), GitHub ([gh-wh]) and CloudEvents' `source`+`id` uniqueness rule ([cloudevents]).
10. **Overload gets a 429, a time to wait, and limits the client can read.** RFC 6585 ([rfc6585]),
    Zalando rule 153 ([zalando]), Heroku's "show rate limit status" ([heroku]) and the IETF
    `RateLimit` draft ([rl-draft]). OWASP ranks "Unrestricted Resource Consumption" fourth in its
    API Security Top 10 ([owasp]).

### Real disagreements (the reviewer must not pick a side unless the API has none)

| Topic | Positions | Sources |
|---|---|---|
| JSON property casing | snake_case (Zalando rule 118; Heroku lower-cases paths and attributes) against camelCase (Azure). Google defines fields in lower_snake_case in proto and maps them to "an appropriate" JSON convention. | [zalando], [heroku], [msazure], [aip140] |
| Where the version lives | Not at all, through media types (Zalando 113 to 115, which forbid URL versions). Major version in the path, `v1` (Google, GDS). Required `api-version` date query parameter (Azure). A date pinned per account with a `Stripe-Version` header override (Stripe). The Accept header (Heroku). Versionless (GraphQL). | [zalando], [aip185], [gds], [msazure], [stripe-ver], [heroku], [gql-schema] |
| Error body shape | RFC 9457 problem details (Zalando MUST; Redocly has an optional rule). Azure's own `error{code,message}` plus a header. Google's `google.rpc.Status` with `ErrorInfo`. | [rfc9457], [zalando], [redocly], [msazure], [aip193] |
| Where pagination links go | `Link` response header (GitHub, RFC 8288). A body field such as `nextLink` (Azure) or `next_page_token` (Google). Relay `pageInfo` for GraphQL. Total counts: Zalando says avoid them; Google allows a documented estimate. | [gh-pag], [rfc8288], [msazure], [aip158], [relay], [zalando] |
| Which methods must be idempotent | Azure: all of them, with POST covered by repeatability headers. Zalando: POST and PATCH idempotency is a SHOULD and `Idempotency-Key` is a MAY. Stripe: every v1 POST accepts a key. | [msazure], [zalando], [stripe-idem] |
| Boolean names | Google: omit the `is` prefix. Redocly ships a configurable `boolean-parameter-prefixes` rule that requires one. | [aip140], [redocly] |
| Nulls | Azure: never send null fields; null in a request only means "delete" in a JSON Merge Patch. GraphQL: every field is nullable by default so a partial failure returns null for one field. | [msazure], [rfc7396], [gql-schema] |
| Rate-limit headers | `X-RateLimit-*` with a relative reset, or `Retry-After` (Zalando, which notes GitHub and Twitter use epoch seconds under the same header name). The IETF draft's `RateLimit` and `RateLimit-Policy` (still a draft at revision 11). | [zalando], [rl-draft] |
| REST purity and HATEOAS | Experts in Kotstein and Bogner's Delphi study rated Richardson maturity level 2 rules (resources plus correct verbs and status codes) critical and level 3 (hypermedia) less important. Hacker News commenters doubt anyone consumes HATEOAS. | [kotstein], [hn-better] |
| API keys | GDS: avoid API keys and basic auth; use OAuth 2.0 with scopes. Stripe authenticates with secret API keys. | [gds], [stripe-idem] |
| Webhook payload | Thin (IDs only, fetch the rest) against full. Standard Webhooks lays out the trade-off and calls thin more future-proof. Stripe now labels thin "recommended". | [stdwh], [stripe-wh] |
| Response envelopes | Hacker News is split ("always use a response envelope" against "unnecessary cruft"). Azure requires an object with a `value` array for lists. | [hn-better], [msazure] |

The lesson for the reviewer: on these rows, "the guide says X" is never a finding by itself. The
finding is "this change differs from what this API already does", or, for a first endpoint, "pick
one and record it".

---

## 2. Catalogue

Column meanings:
- **Principle**: stated generally, protocol-neutral where possible.
- **Violation in a diff**: what the reviewer actually sees.
- **Tool check**: whether a linter, a breaking-change differ or a short script could catch it,
  and which one. "Judgement" means no reliable mechanical check exists.
- **#**: how many independent organisations or papers state it (one company's several documents
  count once).
- **Sources**: URL keys from the list at the end.

### 2.1 Naming and consistency

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| One term per concept, across the whole API; one concept per term. | A new field `customer_id` where siblings say `client_id`; `user` meaning two different things. | Partial: a script that lists every field and parameter name in the spec and flags near-synonyms is cheap. Deciding which synonym is right is judgement. | 5 | [aip190], [dotnet], [azsdk], [bloch], [postman] |
| One casing style per element type (paths, fields, query parameters, headers, enum values), matching the API's existing style. | A camelCase field in a snake_case API; `/userProfiles` beside `/order-items`. | Yes: Spectral custom `casing` rule, Redocly `paths-kebab-case`, GraphQL-ESLint `naming-convention`, buf lint. A script can also infer the majority style from the existing spec. | 6 | [zalando], [msazure], [aip140], [heroku], [redocly], [gql-eslint], [buf-lint] |
| Collection names are plural nouns; paths carry no verbs or CRUD words. | `POST /createUser`, `GET /user/list`, `/getOrders`. | Yes: Redocly `path-segment-plural` and `no-http-verbs-in-paths`. | 4 | [zalando], [redocly], [bogner], [heroku] |
| Names are specific, familiar and unabbreviated unless the abbreviation is standard. | Fields named `data`, `info`, `val2`, `tmpFlag`. | Partial: a list of banned vague words; the rest is judgement. | 4 | [aip190], [aip140], [bloch], [rust] |
| Parameters appear in the same order everywhere; short parameter lists. | A new function takes `(dst, src)` where siblings take `(src, dst)`; five positional booleans. | Partial: parameter-count limit via a language linter; ordering is judgement. | 3 | [bloch], [rust], [go-compat] |
| Language-native conventions in SDKs and libraries (getters, conversions, iterators, casing). | A Rust `get_name()` getter, a Python `getName()`, a Go `GetFoo` on a non-interface type. | Yes for casing (clippy, ruff/pylint, golint-style linters); judgement for idiom. | 3 | [rust], [azsdk], [dotnet] |

### 2.2 Resource and operation shape

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Methods keep their protocol meaning: GET and other safe methods have no side effects; PUT and DELETE are idempotent. | A GET route that writes; a POST used to tunnel an update. | Partial: a script can flag GET handlers that call write paths; mostly judgement. | 4 | [rfc9110], [bogner], [zalando], [aip136] |
| Use standard operations (get, list, create, update, delete) where they fit; add a custom action only where they do not, and name it as a verb. | `POST /orders/123/doUpdate` for a plain field update; a custom `archive` modelled as `PATCH status=archived` with hidden side effects. | Judgement. | 3 | [aip136], [bogner], [heroku] |
| Request and response shapes are designed for callers, not copied from storage models. | A response that is an ORM row with internal columns; one proto message used for both storage and RPC. | Judgement (a script can flag fields named like internal columns, such as `password_hash` or `_internal`). | 3 | [pb-dos], [hn-worst], [owasp] |
| A list always returns a list, even with zero or one item; never null for "none". | A response that returns a bare object for one result and an array for many, or `null` for no results. | Yes, from the schema: the response type is a union of object and array, or the array is nullable. | 3 | [hn-hate], [msazure], [aip158] |
| Avoid making callers do work the API could do (N+1 calls, boilerplate). | A list endpoint that returns only IDs, forcing one call per item. | Judgement. | 3 | [bloch], [hn-hnapi], [hn-worst] |
| Prefer an enum to a boolean that may later need a third state. | A new `bool is_active` on a status that is likely to grow. | Judgement. | 2 | [pb-dos], [rust] |
| Operations taking more than about a second run as long-running operations with a status resource and `Retry-After`. | A synchronous endpoint that does a multi-minute export. | Judgement. | 2 | [msazure], [hn-hate] |
| Times are UTC in ISO 8601 / RFC 3339; IDs are opaque strings. | A new `created` field as local time or epoch seconds in an API that uses RFC 3339. | Yes: schema `format: date-time` check; a script for consistency with sibling fields. | 4 | [gds], [heroku], [cloudevents], [aip180] |

### 2.3 Errors

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Use the correct, most specific status code; never 200 for an error. | `return 200, {"success": false}`; a 500 for bad input; 404 and 403 swapped. | Partial: grep handlers for success codes paired with error bodies; Spectral/Redocly `operation-4xx-response`. | 6 | [rfc9110], [zalando], [gds], [bogner], [heroku], [hn-hate] |
| Every error carries a stable, machine-readable code, separate from the human message, and the same shape everywhere. | A new handler that returns a plain string, or a different error shape from the rest of the API. | Yes: Redocly `operation-4xx-problem-details-rfc7807`; a Spectral rule that every 4xx/5xx response references the shared error schema. | 6 | [rfc9457], [zalando], [msazure], [aip193], [grpc-err], [gds] |
| Messages are short, say what went wrong and how to fix it; dynamic values go in structured fields, not only in text. | "Error occurred"; a message that embeds an ID the client must parse out. | Judgement (a script can flag generic strings like "error", "failed", "something went wrong"). | 4 | [aip193], [azsdk], [bloch], [hn-better] |
| Never expose stack traces or internal details. | An exception handler that returns `str(e)` or a traceback. | Partial: grep for traceback or `err.stack` in responses. | 3 | [zalando], [gds], [owasp] |
| 405 responses list the allowed methods; 429 and 503 say when to retry. | A 405 with no `Allow` header. | Yes: a contract test or a script over route tables. | 3 | [rfc9110], [rfc6585], [msazure] |
| Libraries fail fast with meaningful error types and document every failure. | A Rust function returning `Result<T, String>`; a doc comment with no "Errors" section; panicking on bad input. | Partial: clippy `missing_errors_doc`; judgement for the rest. | 3 | [rust], [bloch], [azsdk] |

### 2.4 Pagination and filtering

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Every collection endpoint that can grow is paginated from its first release. | A new `GET /items` that returns everything. | Yes: a Spectral rule that list operations (GET on a collection path, or `List*` RPCs) declare page parameters. | 5 | [aip158], [zalando], [msazure], [gh-pag], [relay] |
| Page tokens or cursors are opaque; prefer cursors over offsets for large or changing sets. | `?page=3&offset=200` on a hot table; a token that is base64 of a visible offset. | Partial: a schema check for `offset` parameters; judgement on opacity. | 4 | [aip158], [zalando], [relay], [hn-better] |
| The last page is signalled unambiguously; a default and maximum page size are documented, and larger requests are reduced, not rejected. | `next` set to null in an API that omits it on the last page; no documented maximum. | Partial: a schema check for documented default and maximum. | 3 | [aip158], [msazure], [gh-pag] |
| Unsupported filter or query parameters return an error, not silent ignore. | A handler that drops unknown query parameters. | Partial: contract tests. | 2 | [msazure], [aip158] |

### 2.5 Versioning and compatibility

(Only applies when the API has outside callers; see section 3.)

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| No removal or rename of operations, fields, parameters, enum values, flags or exported symbols within a major version. | A field deleted from a response schema; a CLI flag renamed; an exported function removed. | Yes: oasdiff `breaking`, buf breaking, GraphQL Inspector diff, cargo-semver-checks, gorelease, API Extractor reports, japicmp. | 8 | [aip180], [zalando], [msazure], [stripe-ver], [go-compat], [clig], [pb-dos], [gql-schema] |
| No new required input. New optional inputs default to the old behaviour. | A new required request field or positional argument; a new function parameter in Go. | Yes: oasdiff, buf, GraphQL Inspector, cargo-semver-checks. | 5 | [aip180], [pb-dos], [go-compat], [zalando], [stripe-sdkver] |
| No change to a field's type, format, default, or serialization of defaults. | `int` to `string`; a default flipped; a field now always present. | Yes for type changes (all diff tools); defaults partly; serialization is judgement. | 3 | [aip180], [pb-dos], [buf-breaking] |
| Wire identifiers are never reused (proto field numbers, enum numbers); deleted ones are reserved. | A proto field removed without `reserved`; a number reused. | Yes: buf breaking `FIELD_NO_DELETE_UNLESS_NUMBER_RESERVED`. | 2 | [pb-dos], [buf-breaking] |
| Clients must tolerate additions: unknown fields and new enum values. Producers document enums as extensible. | A closed enum in a response; client code that fails on an unknown value. | Partial: a schema check that response enums are marked extensible (Zalando `x-extensible-enum`); judgement for client code. | 4 | [zalando], [msazure], [aip180], [stripe-wh] |
| Behaviour that callers can observe is part of the contract (ordering, timing, error text). | Sorting order of a list changed; an error message reworded that clients matched on. | Judgement. | 3 | [hyrum], [aip193], [aip180] |
| Breaking changes ship only with a new major version and a migration path. | A breaking diff with no version bump. | Yes: oasdiff fails the build when a breaking change lacks a major bump; cargo-semver-checks; gorelease. | 4 | [semver], [oasdiff], [cargo-semver], [stripe-sdkver] |
| Deprecate before removal: mark in the spec, send `Deprecation` and `Sunset` at runtime, give a reason and date, and link to the migration. | A field removed with no prior deprecation; `@deprecated` with no reason. | Yes: GraphQL-ESLint `require-deprecation-reason`/`-date`; a Spectral rule that deprecated operations carry a sunset extension; grep for headers. | 5 | [rfc9745], [rfc8594], [zalando], [gql-eslint], [aip185] |
| Release notes record every significant change. | A public-surface change with no changelog entry. | Partial: a script that requires a changelog edit when the public surface changes. | 3 | [rust], [oasdiff], [gds] |

### 2.6 Idempotency and retries

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Non-idempotent creates and charges accept a client-generated idempotency key. Repeats return the first result. A reused key with different parameters is an error. | A new payment or create endpoint with no key; a key implementation that re-executes on retry. | Partial: a Spectral rule that POST operations declare the API's key header or field; judgement on server logic. | 6 | [stripe-idem], [aws-idem], [aip155], [msazure], [zalando], [idem-draft] |
| A retried create should not return "already exists" to the original caller. | Retry of a create yields 409 with no way to tell it was your own request. | Judgement. | 2 | [aws-idem], [aip155] |
| Clients and SDKs retry with exponential backoff and jitter, and only retry safe or keyed requests. | An SDK that retries every POST in a tight loop. | Judgement. | 3 | [aws-backoff], [stdwh], [rfc6585] |

### 2.7 Authentication and authorisation surface

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Every operation declares its security requirement in the contract. | A new operation with no `security` entry. | Yes: Spectral `oas3-operation-security-defined`, Redocly `security-defined`. | 3 | [spectral-oas], [redocly], [gds] |
| Authorisation is checked per object and per property, not just per route. | A handler that loads `/orders/{id}` without checking ownership; a PATCH that lets a caller set `role`. | Judgement (the top two OWASP API risks). | 3 | [owasp], [aip193], [gds] |
| Check permission before existence so a 404 does not leak that a resource exists. | 404 to an unauthorised caller for an object that exists, 403 for one that does not. | Judgement. | 1 | [aip193] |
| Credentials never travel in URLs or CLI flags. | `?api_key=` in a new route; a `--password` flag. | Yes: a grep for credential-looking query parameters and flags. | 4 | [rfc6750], [clig], [gh-wh], [hn-lie] |
| TLS is required; scopes are granular. | A new HTTP (not HTTPS) server URL in the spec. | Yes: Spectral server rules for the URL scheme. | 3 | [gds], [heroku], [rfc9700] |
| Page tokens grant no authorisation. | A cursor that encodes a tenant ID which the server trusts. | Judgement. | 1 | [aip158] |

### 2.8 Rate limits

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Throttle with 429 and say when to retry (`Retry-After`), and expose current limits in headers. | A new limiter that returns 403 or 500; no `Retry-After`. | Partial: grep and contract test; Spectral rule that 429 responses declare headers. | 4 | [rfc6585], [zalando], [heroku], [rl-draft] |
| Every endpoint that consumes real resources has limits (size, rate, page size). | An upload endpoint with no size limit; a page-size parameter with no maximum. | Partial: schema check for `maxLength`/`maximum` on size and count parameters. | 2 | [owasp], [aip158] |

### 2.9 Documentation and examples

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Every public operation, parameter and type has a description. | A new operation or exported function with no doc. | Yes: Spectral `operation-description`, `oas3-parameter-description`; Redocly `operation-summary`; GraphQL-ESLint `require-description`; Rust `missing_docs`. | 5 | [spectral-oas], [redocly], [gql-eslint], [rust], [zalando] |
| Examples exist and are valid against the schema; examples are runnable. | No example for a new endpoint; an example that no longer matches the schema after a field change. | Yes: Spectral `oas3-valid-media-example`, Redocly `no-invalid-media-type-examples`; doctests for libraries. | 5 | [spectral-oas], [redocly], [rust], [heroku], [robillard] |
| Docs explain intent, failure modes, and consistency guarantees, not only signatures. | A doc that lists parameters but not which errors occur or whether the call is eventually consistent. | Judgement. | 4 | [robillard], [rust], [hn-hate], [azsdk] |
| Docs show the path from a usage scenario to the API calls (tutorials, cookbooks). | A new feature that adds endpoints but no guide. | Judgement. | 3 | [robillard], [azsdk], [gds] |
| Stability level is stated (alpha, beta, stable). | A new endpoint with no stability marker in an API that marks them. | Partial: a spec extension check. | 3 | [heroku], [aip185], [oasdiff] |

### 2.10 Discoverability

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| The contract is complete: every route in code appears in the spec, every spec path exists in code. | A new route registered in code but missing from `openapi.yaml`. | Yes: a script comparing framework route tables with the spec; Optic or contract tests. | 3 | [zalando], [owasp], [gds] |
| Spec hygiene: unique operation IDs, defined tags, no unused components, no ambiguous paths. | Duplicate `operationId`; two paths that match the same URL. | Yes: Spectral `operation-operationId-unique`, `oas3-unused-component`; Redocly `no-ambiguous-paths`. | 2 | [spectral-oas], [redocly] |
| Core use cases are easy to find; concepts are revealed step by step. | A primary task that needs an obscure option buried in a config object. | Judgement. | 3 | [azsdk], [bloch], [cmu-natprog] |
| Track the inventory of versions and hosts; no forgotten debug endpoints. | A `/debug` or `/internal` route exposed on the public router. | Partial: grep routes for debug names. | 1 | [owasp] |

### 2.11 SDK and library ergonomics

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Easy to use without docs, hard to misuse. Types carry meaning; avoid bare `bool`/`Option` arguments. | `send(true, false, null)`; stringly typed IDs. | Judgement (a linter can flag boolean positional parameters). | 3 | [bloch], [rust], [myers] |
| Hide implementation; keep room to evolve (private fields, sealed traits, concrete return types, option structs). | A public struct with public fields; a Go constructor returning an interface; a new interface method. | Yes: cargo-semver-checks, gorelease, API Extractor reports the surface; judgement on design. | 3 | [rust], [go-compat], [dotnet] |
| Builders or option objects for complex construction; avoid long parameter lists. | A constructor with seven parameters. | Partial: parameter-count lint. | 3 | [rust], [bloch], [go-compat] |
| Make network calls, defaults and retries visible; errors are diagnosable. | An SDK method that silently retries or swallows an error. | Judgement. | 2 | [azsdk], [rust] |
| Public types implement the language's common traits or interfaces (Debug, equality, serialization). | A new public Rust type without `Debug`. | Yes: rustc `missing_debug_implementations`. | 2 | [rust], [dotnet] |
| A CLI used by scripts: exit codes, machine output on stdout and messages on stderr, `--json`, no required prompts, flags over positional arguments, stable flags. | A command that prints errors to stdout and exits 0; a new interactive prompt with no flag. | Partial: a script runs the CLI with `--help`, `--json`, closed stdin and checks the exit code. | 1 (one dedicated guide) | [clig] |

### 2.12 Events and webhooks

| Principle | Violation in a diff | Tool check | # | Sources |
|---|---|---|---|---|
| Every delivery is signed (HMAC or asymmetric) over ID, timestamp and body; receivers verify the timestamp is within tolerance. | A new webhook sender with no signature; a receiver that skips verification or uses tolerance 0. | Partial: grep for signing in senders and verification in handlers. | 3 | [stdwh], [stripe-wh], [gh-wh] |
| Every event has a unique, stable ID kept across retries; consumers deduplicate by it. | An event with no ID; an ID regenerated on retry. | Yes: schema check (AsyncAPI or the event type) that `id` is required. | 4 | [stdwh], [cloudevents], [stripe-wh], [gh-wh] |
| One event type, one schema; the type name is explicit. | A `type` value whose payload shape varies with other fields. | Partial: AsyncAPI document lint. | 3 | [stdwh], [cloudevents], [asyncapi] |
| Delivery retries with exponential backoff and jitter; only 2xx is success; ordering is not guaranteed. | A consumer that assumes `created` before `updated`; a sender with no retry. | Judgement. | 3 | [stdwh], [stripe-wh], [gh-wh] |
| Receivers acknowledge fast and process asynchronously. | A handler that does slow work before returning 200. | Judgement. | 3 | [stripe-wh], [gh-wh], [stdwh] |
| Senders guard against SSRF when calling caller-supplied URLs. | A webhook dispatcher that posts to any URL, including internal addresses. | Judgement. | 2 | [stdwh], [owasp] |
| Event payloads are described in a contract (AsyncAPI or CloudEvents `dataschema`). | A new event type with no schema. | Yes: presence check. | 2 | [asyncapi], [cloudevents] |

### 2.13 What developers complain about (cross-check for the catalogue)

These recurring complaints map onto the rows above, which confirms the catalogue covers what
hurts in practice:

- 200 OK for errors, bare 404s that do not say whether the resource or the route is missing,
  a null array for "no items", a bare object for one result ([hn-hate]).
- Undocumented mix of strong and eventual consistency ([hn-hate]).
- No example code; hundreds of lines to make a first connection ([hn-hate]).
- Endpoints that return only IDs and force one request per item ([hn-hnapi]).
- A designer's mental model far from the caller's; CRUD wrappers that push bookkeeping onto the
  client ([hn-worst]).
- Auth tokens in URLs; onerous key sign-up ([hn-lie]).
- Bugs, poor documentation, "never-ending API changes" and slow responses, in a 2011 developer
  survey ([tc-fb]).
- Parseable errors with standard codes, cursor rather than offset pagination, and OpenAPI for
  generated clients are the commonest positive advice in the "How to Design Better APIs" thread
  ([hn-better]).

---

## 3. Which checks depend on outside callers

idleflow's "unreleased" mode skips compatibility work. The guides support this split explicitly.
SemVer says "Major version zero (0.y.z) is for initial development. Anything MAY change at any
time" ([semver]). Google lets alpha channels be shut down at any time and gives beta a deprecation
period ([aip185]). Zalando classifies every API by audience (from `component-internal` to
`external-public`) and requires the review process only for APIs whose audience is not
component-internal ([zalando]).

### Skipped in unreleased mode (only matter once someone outside depends on the API)

- Removal, rename or type change of any operation, field, parameter, enum value, flag, event type
  or exported symbol (section 2.5, rows 1 to 4).
- New required inputs and changed defaults.
- Semantic or observable behaviour changes covered by Hyrum's Law, including error message text
  ([hyrum], [aip193]).
- Version bumps, `Deprecation`/`Sunset` headers, deprecation reasons and dates, migration guides
  ([rfc9745], [rfc8594], [gql-eslint]).
- Changelog entries for breaking changes.
- CLI flag and output stability ([clig]).
- Running oasdiff, buf breaking, GraphQL Inspector diff, cargo-semver-checks, gorelease or API
  Extractor in "fail on breaking" mode.

### Still apply in unreleased mode

Everything else: naming, consistency, operation shape, errors, pagination, idempotency, auth,
rate limits, docs, discoverability, SDK ergonomics, webhooks.

### Become more important in unreleased mode

Some choices are free before release and breaking afterwards, so the reviewer should push them
hardest while the API is unreleased:

- Add pagination now: adding it later is breaking ([aip158]).
- Use extensible enums and enums instead of booleans that may grow ([zalando], [pb-dos]).
- Keep fields private and return concrete types or option structs, so the surface can grow
  ([rust], [go-compat]).
- Use opaque IDs and page tokens ([aip158], [heroku]).
- Prefer CLI flags to positional arguments and avoid a catch-all default subcommand ([clig]).
- Pick the error shape, versioning scheme and casing once, and record them as the API's
  conventions.

### Caveats the reviewer should check before trusting "unreleased"

"No outside callers" is about any consumer the diff cannot update in the same change:
- Persisted data. Protobuf field numbers and event payloads already written to disk or a queue
  are read back later, so wire-compatibility rules (no reused field numbers) still apply
  ([pb-dos], [buf-breaking]).
- Installed clients such as mobile apps, published packages, or other repositories.
- Webhooks already registered by anyone.
- A signal that the API is in fact released: git tags, a published package version at or above
  1.0.0, a deployed production URL in the spec's `servers`, or a stability marker of beta or
  stable.

---

## 4. What the reviewer agent needs

### 4.1 Inputs

1. **The diff and its base**, so before and after contracts can be compared.
2. **Contract files**, found by name and content: `openapi.*`, `swagger.*`, `*.graphql`/SDL,
   `*.proto` and `buf.yaml`, `asyncapi.*`, JSON Schema files, CloudEvents type definitions.
3. **Route and handler definitions** when no spec exists: framework routers (Express, FastAPI,
   Flask, Django, Rails, Spring annotations, Go `net/http` muxes), GraphQL resolvers, gRPC service
   implementations.
4. **Request and response models**: validation schemas (Pydantic, Zod, serializers), DTOs, error
   types.
5. **The public surface of libraries**: exported symbols (`index.ts` exports, Python `__all__`,
   Rust `pub` items, Go exported identifiers, Java `public`), generated API reports where they
   exist.
6. **CLI definitions**: argument parser declarations (argparse, click, cobra, clap) and help text.
7. **Event producers and consumers**: where events are built, signed, sent and handled.
8. **Docs**: README, `docs/`, changelog, examples, doc comments.
9. **Release status**: idleflow's mode (released or unreleased), plus tags, package versions and
   stability markers to cross-check it (section 3).
10. **Existing house conventions**: either a written style file in the repo, or conventions the
    reviewer derives from the unchanged part of the API (section 4.3).

### 4.2 Mechanical checks and judgement checks

**Mechanical** (run a tool or a script, report its output as evidence):
- Spec lint: Spectral `spectral:oas` ([spectral-oas]) or Redocly ([redocly]) or vacuum
  ([vacuum]); Spectral-based house rule sets exist from Zalando (Zally, [zally]), Azure
  ([azure-validator]) and IBM ([ibm-validator]). Covers operation IDs, descriptions, examples
  valid against schemas, security defined, path hygiene, 2xx and 4xx responses.
- Schema lint for other formats: GraphQL-ESLint ([gql-eslint]), buf lint ([buf-lint]).
- Breaking-change diff (released mode only): oasdiff ([oasdiff]), buf breaking ([buf-breaking]),
  GraphQL Inspector ([gql-insp]), cargo-semver-checks ([cargo-semver]), gorelease ([gorelease]),
  API Extractor ([api-extractor]), japicmp ([japicmp]), Optic ([optic]).
- Short scripts: majority casing per element type and outliers in the diff; list operations
  without page parameters; error responses not referencing the shared error schema; routes in
  code but not in the spec and the reverse; credential-looking query parameters or flags; `200`
  returned with error-shaped bodies; 405 without `Allow`; 429 without `Retry-After`; new event
  types without a required `id`; deprecated items without a reason or date; a public-surface
  change with no changelog edit.

**Judgement** (the reviewer reasons and cites the principle):
- Whether names are clear and consistent in meaning, not only in casing.
- Resource modelling and whether a custom action is warranted.
- Whether error messages are actionable.
- Whether docs explain intent, failures and consistency.
- Whether the design makes callers do avoidable work (N+1 calls, boilerplate).
- Authorisation per object and per property.
- Semantic behaviour changes in released mode (Hyrum's Law).
- Thin versus full webhook payloads; whether a boolean should be an enum; whether an operation
  should be long-running.
- SDK ergonomics: misuse resistance, defaults, visibility of network calls.

Research supports treating some rules as evidence-backed and not mere opinion: Bogner et al.
found that violating 11 of 12 tested REST rules (plural nouns, no CRUD words in paths, correct
verbs, no 200 for errors, 401 for credential problems, 415 for media type) significantly worsened
comprehension ([bogner]). The reviewer can give these more weight than rules with no evidence.

### 4.3 Respecting the API's own conventions over generic advice

The sources justify this order directly: Azure ranks consistency within the language and service
above cross-language parity ([azsdk]); Google asks for one term per concept ([aip190]); the guides
themselves disagree on casing, versioning, error shape and pagination (section 1). A reviewer that
applies one company's guide to another company's API produces noise.

Procedure:

1. **Look for a written convention first** (a style file, a linter config such as `.spectral.yaml`,
   an existing ruleset). If present, it is the standard.
2. **Otherwise derive the conventions from the unchanged API**: casing per element type, error
   body shape, pagination style, version scheme, ID and timestamp formats, auth scheme, idempotency
   mechanism, event envelope. Use the majority pattern and note the count (for example "41 of 43
   fields are snake_case").
3. **Judge new and changed elements against the house convention.** A mismatch is a finding even
   when the new element follows a published guide better.
4. **Do not recommend changing an established convention** in a change that only adds to the API.
   Migrating a convention is a separate, deliberate decision, and in released mode it is itself a
   breaking change. At most, record it as an observation.
5. **When there is no convention yet** (the first endpoint, or a new API), recommend the
   standards-based default and ask that the choice be recorded: RFC 9457 errors ([rfc9457]),
   cursor pagination ([aip158]), RFC 3339 times, a client-supplied idempotency key
   ([idem-draft]), `Retry-After` on 429 ([rfc6585]). For the rows in the "Real disagreements" table,
   present the options rather than one answer.
6. **When house conventions conflict with each other**, flag the inconsistency and recommend the
   majority pattern for new code.
7. **Some findings hold regardless of house style**: security issues from the OWASP API Top 10
   ([owasp]); credentials in URLs ([rfc6750]); breaking changes in released mode; violations of a
   MUST in an RFC the API claims to follow (for example GET with side effects, [rfc9110]). Even
   then, if the house style itself does the wrong thing (for example 200 for errors throughout),
   the reviewer should report it as an observation and not demand that the new endpoint alone
   behave differently, since that adds inconsistency.

Suggested finding format: principle (from the catalogue), the file and line, the house convention
or the source it violates with its URL, whether a tool confirmed it, and severity. Blocking only
for: a breaking change in released mode without a version or deprecation path; a security issue;
a conflict with the house convention; or a protocol MUST violated in new code.

---

## Sources

IETF standards and drafts
- [rfc9110]: https://www.rfc-editor.org/rfc/rfc9110.html (HTTP Semantics; idempotent methods 9.2.2; 405 requires `Allow`; 422)
- [rfc9457]: https://www.rfc-editor.org/rfc/rfc9457.html (Problem Details for HTTP APIs, obsoletes RFC 7807)
- [rfc8288]: https://www.rfc-editor.org/rfc/rfc8288.html (Web Linking, `Link` header)
- [rfc8594]: https://www.rfc-editor.org/rfc/rfc8594.html (`Sunset` header)
- [rfc9745]: https://www.rfc-editor.org/rfc/rfc9745.html (`Deprecation` header, March 2025)
- [rfc6585]: https://www.rfc-editor.org/rfc/rfc6585.html (429 Too Many Requests, `Retry-After`)
- [rfc7396]: https://www.rfc-editor.org/rfc/rfc7396.html (JSON Merge Patch)
- [rfc6750]: https://www.rfc-editor.org/rfc/rfc6750.html (Bearer tokens)
- [rfc9700]: https://www.rfc-editor.org/rfc/rfc9700.html (OAuth 2.0 Security Best Current Practice)
- [idem-draft]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/ (Idempotency-Key header; Datatracker listed revision -07 of October 2025 as an expired draft when checked; repository https://github.com/ietf-wg-httpapi/idempotency)
- [rl-draft]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/ (`RateLimit` and `RateLimit-Policy`, still an Internet-Draft at revision 11)

Provider and government guidelines
- [aip136]: https://google.aip.dev/136 (custom methods)
- [aip140]: https://google.aip.dev/140 (field names)
- [aip155]: https://google.aip.dev/155 (request IDs)
- [aip158]: https://google.aip.dev/158 (pagination)
- [aip180]: https://google.aip.dev/180 (backwards compatibility)
- [aip185]: https://google.aip.dev/185 (versioning)
- [aip190]: https://google.aip.dev/190 (naming)
- [aip193]: https://google.aip.dev/193 (errors)
- [msazure]: https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md
- [zalando]: https://opensource.zalando.com/restful-api-guidelines/
- [heroku]: https://github.com/interagent/http-api-design (table of contents at https://github.com/interagent/http-api-design/blob/master/en/SUMMARY.md)
- [gds]: https://www.gov.uk/guidance/gds-api-technical-and-data-standards
- [stripe-ver]: https://stripe.com/blog/api-versioning
- [stripe-idem]: https://docs.stripe.com/api/idempotent_requests
- [stripe-wh]: https://docs.stripe.com/webhooks
- [stripe-sdkver]: https://docs.stripe.com/sdks/versioning
- [aws-idem]: https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/
- [aws-backoff]: https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
- [gh-pag]: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api
- [gh-wh]: https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks
- [owasp]: https://owasp.org/API-Security/editions/2023/en/0x11-t10/ (OWASP API Security Top 10, 2023)

GraphQL, gRPC, Protocol Buffers, events
- [gql-schema]: https://graphql.org/learn/schema-design/
- [gql-bp]: https://graphql.org/learn/best-practices/
- [relay]: https://relay.dev/graphql/connections.htm
- [pb-dos]: https://protobuf.dev/best-practices/dos-donts/
- [grpc-err]: https://grpc.io/docs/guides/error/
- [stdwh]: https://github.com/standard-webhooks/standard-webhooks/blob/main/spec/standard-webhooks.md (site: https://www.standardwebhooks.com/)
- [cloudevents]: https://github.com/cloudevents/spec/blob/main/cloudevents/spec.md
- [asyncapi]: https://www.asyncapi.com/docs/reference/specification/v3.0.0

Library, SDK and CLI guides
- [rust]: https://rust-lang.github.io/api-guidelines/checklist.html
- [azsdk]: https://azure.github.io/azure-sdk/general_introduction.html
- [dotnet]: https://learn.microsoft.com/en-us/dotnet/standard/design-guidelines/
- [go-compat]: https://go.dev/blog/module-compatibility
- [semver]: https://semver.org/
- [hyrum]: https://www.hyrumslaw.com/
- [bloch]: https://www.cin.ufpe.br/~if669/files/MaterialDeEnsino/Referencias/api-design-oopsla-2006.pdf (Joshua Bloch, "How to Design a Good API and Why it Matters", OOPSLA 2006 slides)
- [clig]: https://clig.dev/

Linters and breaking-change tools
- [spectral-oas]: https://github.com/stoplightio/spectral/blob/develop/docs/reference/openapi-rules.md
- [redocly]: https://redocly.com/docs/cli/rules/built-in-rules
- [vacuum]: https://github.com/daveshanley/vacuum
- [zally]: https://github.com/zalando/zally
- [azure-validator]: https://github.com/Azure/azure-openapi-validator
- [ibm-validator]: https://github.com/IBM/openapi-validator
- [gql-eslint]: https://the-guild.dev/graphql/eslint/rules
- [gql-insp]: https://the-guild.dev/graphql/inspector/docs
- [buf-lint]: https://buf.build/docs/lint/rules/
- [buf-breaking]: https://buf.build/docs/breaking/rules/
- [oasdiff]: https://github.com/oasdiff/oasdiff
- [optic]: https://github.com/opticdev/optic
- [cargo-semver]: https://github.com/obi1kenobi/cargo-semver-checks
- [gorelease]: https://pkg.go.dev/golang.org/x/exp/cmd/gorelease
- [api-extractor]: https://api-extractor.com/pages/overview/intro/
- [japicmp]: https://github.com/siom79/japicmp

Research and surveys
- [robillard]: https://www.cs.mcgill.ca/~martin/papers/ese2011.pdf (Robillard and DeLine, "A field study of API learning obstacles", Empirical Software Engineering 16, 2011)
- [myers]: https://doi.org/10.1145/2896587 (Myers and Stylos, "Improving API Usability", CACM 59(6), 2016)
- [cmu-natprog]: https://www.cs.cmu.edu/~NatProg/apiusability.html (index of CMU API usability studies)
- [murphy]: https://research.google/pubs/preliminary-analysis-of-rest-api-style-guidelines/ (Murphy, Alliyu, Kery, Myers, PLATEAU 2017; 32 REST guides compared)
- [kotstein]: https://arxiv.org/abs/2108.00033 (Kotstein and Bogner, Delphi study of 82 REST rules)
- [bogner]: https://arxiv.org/abs/2305.07346 (Bogner, Kotstein, Pfaff, experiment with 105 participants on 12 REST rules)
- [postman]: https://www.postman.com/state-of-api/2025/

Developer complaints
- [hn-hate]: https://news.ycombinator.com/item?id=21766781 (discussion of "API Practices If You Hate Your Customers", ACM Queue, https://queue.acm.org/detail.cfm?id=3375635)
- [hn-better]: https://news.ycombinator.com/item?id=30647784 ("How to Design Better APIs")
- [hn-worst]: https://news.ycombinator.com/item?id=36951289 ("The worst API ever made", https://caseymuratori.com/blog_0025)
- [hn-hnapi]: https://news.ycombinator.com/item?id=19052964 ("Hacker News API is not well designed")
- [hn-lie]: https://news.ycombinator.com/item?id=6846371 ("The lie of the API")
- [tc-fb]: https://techcrunch.com/2011/08/11/facebook-wins-worst-api-in-developer-survey
