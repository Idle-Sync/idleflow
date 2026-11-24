# Security review: what published guidance agrees on

Research for an idleflow security reviewer agent that runs beside `review-correct` and `review-conform`
when a task touches authentication, authorisation, input handling, secrets, or defaults that face the
outside. Gathered 2026-11-25. Every claim carries a URL. Where a source was read only through a search
result rather than opened, that is said.

## Source key

The catalogue rows cite these short keys. Each key is one published source.

| Key | Source | URL |
|---|---|---|
| T10 | OWASP Top 10:2025 (A01 Broken Access Control, A02 Security Misconfiguration, A03 Software Supply Chain Failures, A04 Cryptographic Failures, A05 Injection, A06 Insecure Design, A07 Authentication Failures, A08 Software or Data Integrity Failures, A09 Security Logging and Alerting Failures, A10 Mishandling of Exceptional Conditions) | https://top10.owasp.org/2025 |
| API | OWASP API Security Top 10 2023 (API1 BOLA ... API10 Unsafe Consumption of APIs) | https://api-security.owasp.org/editions/2023/en/0x11-t10 |
| ASVS | OWASP ASVS 5.0.0, published 30 May 2025, 17 chapters (V1 Encoding and Sanitization ... V17 WebRTC) | https://asvs.owasp.org/ , chapters: https://github.com/OWASP/ASVS/tree/master/5.0/en |
| CS | OWASP Cheat Sheet Series (individual sheets cited per row) | https://cheatsheetseries.owasp.org/Glossary.html |
| SCR | OWASP Secure Code Review Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Secure_Code_Review_Cheat_Sheet.html |
| CRG | OWASP Code Review Guide 2.0 (2017; project is a "lab project") | https://wiki.owasp.org/images/5/53/OWASP_Code_Review_Guide_v2.pdf , https://owasp.org/www-project-code-review-guide/ |
| C25 | MITRE CWE Top 25, 2025 (39,080 CVE records, 1 June 2024 to 1 June 2025, score = normalised frequency x normalised mean CVSS) | https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html , https://cwe.mitre.org/top25/archive/2025/2025_methodology.html |
| CERT | SEI CERT coding standards (C, C++, Java, Perl) | https://cmu-sei.github.io/secure-coding-standards/sei-cert-oracle-coding-standard-for-java/rules/input-validation-and-data-sanitization-ids , https://wiki.sei.cmu.edu/confluence/display/c/FIO45-C.+Avoid+TOCTOU+race+conditions+while+accessing+files |
| SSDF | NIST SP 800-218 SSDF 1.1 (Feb 2022); SSDF 1.2 draft SP 800-218r1 ipd (17 Dec 2025, comments closed 30 Jan 2026) | https://csrc.nist.gov/pubs/sp/800/218/final , https://csrc.nist.gov/pubs/sp/800/218/r1/ipd |
| OSSF | OpenSSF Security-Focused Guide for AI Code Assistant Instructions (2025-08-01) | https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions |
| CQL | CodeQL CWE coverage table (C/C++, C#, Actions, Go, Java/Kotlin, JS/TS, Python, Ruby, Rust, Swift) | https://codeql.github.com/codeql-query-help/full-cwe/ |
| SG | Semgrep (CE: single-function taint, "community supported" languages; Pro: cross-file) | https://docs.semgrep.dev/semgrep-ce-languages , https://docs.semgrep.dev/semgrep-pro-vs-oss , https://registry.semgrep.dev/tag/owasp |
| BAN | Bandit (Python) | https://bandit.readthedocs.io/en/latest/plugins/index.html , https://bandit.readthedocs.io/en/latest/blacklists/blacklist_calls.html |
| GOS | gosec (Go), every rule mapped to a CWE | https://github.com/securego/gosec , https://raw.githubusercontent.com/securego/gosec/master/RULES.md |
| BRK | Brakeman (Rails) | https://brakemanscanner.org/docs/warning_types/ , https://brakemanscanner.org/docs/confidence/ |
| ESL | eslint-plugin-security (JS) | https://github.com/eslint-community/eslint-plugin-security |

"Sources" in the catalogue counts the standards bodies above (T10, API, ASVS, CS, SCR, CRG, C25, CERT, SSDF, OSSF)
that name the class, then lists the tools. The OWASP documents share many authors, so five OWASP sources
are not five fully independent opinions; the count is a signal of consensus, not a vote.

---

## 1. Where the sources agree and where they differ

### Agreement

1. **Access control is the top risk for web and API code.** Broken Access Control is A01 in T10 2025
   (https://top10.owasp.org/2025/A01_2025-Broken_Access_Control/). Three of the API Top 10 are
   authorisation failures at object, property and function level (API1, API3, API5,
   https://api-security.owasp.org/editions/2023/en/0x11-t10). C25 2025 puts CWE-862 Missing Authorization
   at 4, CWE-863 at 17, CWE-284 at 19, CWE-306 at 21 and CWE-639 at 24
   (https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html). Every source says: deny by default,
   check on the server, check on every request, check the specific object, not just the type
   (https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html).
2. **Injection is prevented by keeping data apart from code**: parameterised queries, argument arrays in place
   of a shell, context-aware output encoding. XSS (1) and SQL injection (2) top C25 2025; Injection is A05 in
   T10; ASVS 5.0 opens with V1 Encoding and Sanitization; CERT IDS00-J says a PreparedStatement still fails if
   input is concatenated into the SQL text
   (https://wiki.sei.cmu.edu/confluence/spaces/java/pages/88487713/IDS00-J.+Prevent+SQL+injection).
3. **Secrets do not belong in code, images or config**, and leaks are fixed by revoking and rotating, not
   just deleting (https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html;
   OSSF; T10 A02 lists CWE-260 password in configuration file,
   https://top10.owasp.org/2025/A02_2025-Security_Misconfiguration/).
4. **Tools help, and do not replace, human review.** CRG: results "need to be understood and triaged by an
   experienced programmer" and a scanner "will not spot a design issue" (CRG 2.0 pp. on false positives,
   https://wiki.owasp.org/images/5/53/OWASP_Code_Review_Guide_v2.pdf). SCR says manual review covers
   business logic, complex authorisation, races and crypto misuse. SSDF PW.7.2 example 4: run a static
   analysis tool "with a human reviewing the issues reported by the tool"
   (https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf). Every tool vendor says the
   same about its own output: Brakeman "can guess wrong"; eslint-plugin-security "finds a lot of false
   positives which need triage by a human".
5. **How hard to review should depend on risk.** CRG 6.5 "A Risk Based Approach to Code Review"; SCR describes
   diff-based reviews for PRs and escalation to a baseline review when a diff finds serious concerns;
   SSDF PW.7.1 leaves the choice of review or analysis to the organisation.
6. **Reuse the vetted control and don't reinvent it.** T10 A01: "implement access control mechanisms once and
   re-use them"; Authorization CS: centralise failure handling; SSDF PW.4: reuse well-secured software,
   "particularly important for software that implements security functionality, such as cryptographic
   modules"; Secrets CS: centralise and standardise.
7. **Fail closed.** T10 A10 2025 maps CWE-636 "Not Failing Securely" and recommends rolling back whole
   transactions (https://top10.owasp.org/2025/A10_2025-Mishandling_of_Exceptional_Conditions/);
   Authorization CS: fail safely.

### Differences

1. **Scope and ranking.** C25 is computed from CVEs across all software, so it carries memory-safety classes
   (CWE-787, 416, 125, 120, 476, 121, 122) that the web-focused OWASP lists do not rank. T10 2025 folded
   SSRF into A01 (CWE-918 is now mapped there) and added two new categories, Software Supply Chain Failures
   (A03) and Mishandling of Exceptional Conditions (A10). The API list adds classes the others barely name:
   unrestricted resource consumption (API4), sensitive business flows (API6), inventory (API9), unsafe
   consumption of third-party APIs (API10).
2. **Denial of service and open redirects.** C25 2025 ranks CWE-770 (no limits or throttling) at 25 and the
   API list makes it API4, while Anthropic's own diff reviewer action excludes "Denial of Service", "Rate
   limiting concerns", "Memory/CPU exhaustion" and "Open redirects" by default as false-positive prone
   (https://github.com/anthropics/claude-code-security-review). CodeQL ships `js/missing-rate-limiting` and
   open-redirect queries for most languages (CQL). The reviewer has to pick a side; section 4 does.
3. **Environment variables for secrets.** OSSF tells assistants to use "environment variables or secure vault
   references". The OWASP Secrets Management CS says to avoid environment variables "unless no other method
   works" because they leak into logs and dumps.
4. **Severity schemes differ**: CVSS 4.0 (https://www.first.org/cvss/v4.0/specification-document), OWASP Risk
   Rating likelihood x impact (https://community.owasp.org/OWASP_Risk_Rating_Methodology), CERT priority =
   severity x likelihood x remediation cost on 1-3 scales giving L1/L2/L3
   (https://wiki.sei.cmu.edu/confluence/display/java/Rule%3A+Priority+and+Levels, read through a search
   result). They are not interchangeable; CVSS scores a vulnerability, CERT scores a rule violation.
5. **Password hashing detail.** The Password Storage CS now calls bcrypt "legacy systems only" and prefers
   Argon2id (m=19 MiB, t=2, p=1), with PBKDF2-HMAC-SHA256 at 600,000 iterations only for FIPS
   (https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). Many framework
   defaults still use bcrypt; treat bcrypt as acceptable-but-not-preferred, not as a finding.
6. **Does AI assistance make code less secure?** Perry et al. (CCS 2023) found it did, and participants were more
   confident (https://arxiv.org/abs/2211.03622). Sandoval et al. (USENIX Security 2023, C only) found the
   assisted group's security-critical bug rate no more than 10% higher than control
   (https://www.usenix.org/conference/usenixsecurity23/presentation/sandoval). See section 3.

---

## 2. Catalogue

Columns: **Class** (general weakness), **Recognise in a diff** (what the reviewer looks at), **CWE**,
**Tools** (which detect it, per language; "judgement" when no tool reliably does), **Sources** (count of
standards bodies, then names), **URLs** (beyond the source key).

CWE definitions are at `https://cwe.mitre.org/data/definitions/<id>.html`.

### 2.1 Authentication

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Missing authentication on a critical function | A new route, handler, RPC method, admin or debug endpoint registered outside the router group or decorator that applies auth; `@public`/`skip_auth`/`permitAll` added | 306, 287 | Judgement. Brakeman "Authentication", "Basic Authentication" (Rails). gosec G108 profiling endpoint exposed (Go) | 5: T10 A07, API2, ASVS V6, SCR, C25 (#21) | https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html |
| Weak password storage | Password hashed with MD5/SHA-1/SHA-256 or unsalted; bcrypt cost < 10; custom KDF; password compared in plaintext | 916, 759, 328 | CQL `py/weak-sensitive-data-hashing`, `js/insufficient-password-hash`, `go/weak-sensitive-data-hashing`, `java/hash-without-salt`, `rb/weak-sensitive-data-hashing`; BAN B324 hashlib, B303 md5; GOS G401; BRK "Weak Hash" | 5: T10 A04, ASVS V6/V11, CS, SCR, OSSF | https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html |
| No brute-force limit on login, OTP, reset | New login/verify/reset endpoint with no rate limit, lockout or backoff | 307, 770 | CQL `js/missing-rate-limiting` (JS only); otherwise judgement | 4: API2/API4, SCR, CS, C25 (#25 for 770) | https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html |
| Broken password reset / account recovery | Reset token predictable, long-lived, not single-use, or the account is identified by an email or account id in the request instead of the token | 640, 620 | CQL `js/host-header-forgery-in-email-generation` (reset link built from Host header). Mostly judgement | 3: SCR, CS, ASVS V6 | https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html |
| Timing-unsafe secret comparison | `==` on tokens, HMACs, API keys instead of a constant-time compare | 208 | ESL `detect-possible-timing-attacks` (JS, noisy); otherwise judgement | 2: OSSF, CS | https://github.com/eslint-community/eslint-plugin-security |
| Hard-coded or default credentials | Literal password, API key, default admin account in code, seed data or config | 798, 259, 1392 | gitleaks, trufflehog (all languages); BAN B105-B107; GOS G101; CQL `*/hardcoded-credentials` (cs, go, java, js, py, rb) | 4: T10 A02/A07, CS, OSSF, SCR (CWE-798 is not in the 2025 Top 25) | https://cwe.mitre.org/data/definitions/1392.html |

### 2.2 Session and token handling

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Session not regenerated on login or privilege change (fixation) | Login handler sets the account into the existing session without rotating the id | 384 | Brakeman "Session Manipulation"/"Session Settings" (Rails); otherwise judgement | 3: ASVS V7, CS, SCR | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html |
| Cookie without Secure / HttpOnly / SameSite | `set_cookie`, `res.cookie`, `http.Cookie{}` for a session or auth cookie missing flags | 614, 1004, 1275 | CQL `py/insecure-cookie`, `go/cookie-secure-not-set`, `java/insecure-cookie`, `js/clear-text-cookie`; GOS G124 | 4: T10 A02 (maps 614, 1004), ASVS V3/V7, CS, SCR | https://top10.owasp.org/2025/A02_2025-Security_Misconfiguration/ |
| No server-side logout / expiry | Logout only deletes the client cookie; no idle or absolute timeout; JWTs with long `exp` and no revocation | 613 | Judgement | 4: T10 A01 (invalidate at logout, short-lived JWTs), ASVS V7/V9, CS, SCR | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html |
| Tokens in browser storage | Session or access token written to `localStorage`/`sessionStorage` | 922 | Judgement | 2: CS (Session Mgmt), ASVS V3 | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html |
| JWT not verified properly | `decode` without verify; algorithm not pinned (accepts `none` or HS/RS confusion); key taken from `jku`/`jwk`/`kid` header; `iss`/`aud` not checked; weak HMAC secret (< 256 bits for HS256) | 347, 345, 321 | CQL `go/parse-jwt-with-hardcoded-key`; otherwise judgement plus the library's own defaults | 4: API2, ASVS V9 Self-contained Tokens, CS, SCR | https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html |
| OAuth/OIDC flow flaws | Missing or constant `state`, no PKCE, redirect URI matched by prefix or regex | 352, 601 | CQL `go/constant-oauth2-state`; otherwise judgement | 2: ASVS V10 OAuth and OIDC, CS | https://cheatsheetseries.owasp.org/cheatsheets/OAuth2_Cheat_Sheet.html |
| Cross-site request forgery | State-changing route on cookie auth with CSRF middleware disabled, exempted, or registered after method-override | 352 | CQL `js/missing-token-validation`, `py/csrf-protection-disabled`, `rb/csrf-protection-disabled`, `java/spring-disabled-csrf-protection`; BRK "Cross-Site Request Forgery"; ESL `detect-no-csrf-before-method-override` | 4: C25 (#3), T10 A01 (maps 352), ASVS V3, CS | https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html |

### 2.3 Authorisation

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Missing authorisation check | Handler loads or mutates data after authentication with no role/permission/policy call; new admin function reachable by any logged-in caller | 862, 285 | Judgement. CQL `cs/web/missing-function-level-access-control` (C# only) | 6: T10 A01, API5, ASVS V8, CS, SCR, C25 (#4) | https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html |
| Object-level authorisation (IDOR / BOLA) | `find(params[:id])`, `get(id)`, `WHERE id = ?` with no owner/tenant filter; id from path or body used directly | 639, 284 | BRK "Unscoped Find" (Rails); CQL `cs/web/insecure-direct-object-reference`; otherwise judgement | 6: T10 A01, API1, ASVS V8, CS, SCR, C25 (#24 for 639) | https://api-security.owasp.org/editions/2023/en/0x11-t10 |
| Property-level authorisation and mass assignment | Request body bound straight to a model (`Model(**request.json)`, `update(req.body)`, `params.permit!`); response serialises the whole model (exposes internal fields) | 915, 213 | BRK "Mass Assignment", "Attribute Restriction"; CQL `rb/insecure-mass-assignment`, JS prototype-pollution queries | 4: API3, CS, ASVS V8, T10 A01 | https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html |
| Incorrect authorisation logic | Role check by string compare against client-supplied value; check uses the wrong subject; `||` where `&&` was meant; authorisation in the client only | 863, 602 | CQL `java/permissive-dot-regex` (narrow); judgement | 5: T10 A01, ASVS V8, CS, SCR, C25 (#17) | https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html |
| Permissive CORS | `Access-Control-Allow-Origin` reflected from request or `*` with credentials | 942, 346 | CQL `js/cors-misconfiguration-for-credentials` | 3: T10 A01 ("minimize CORS usage"), ASVS V3, CS | https://cwe.mitre.org/data/definitions/942.html |
| Unprotected sensitive business flow | Checkout, signup, voucher, transfer endpoints with no anti-automation or limits | 799, 837 | Judgement | 1: API6 | https://api-security.owasp.org/editions/2023/en/0x11-t10 |

### 2.4 Input validation and injection

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| SQL / NoSQL injection | String formatting, concatenation or template literal building a query; raw-query escape hatches (`.raw()`, `extra()`, `Sequelize.literal`) with input | 89, 943 | CQL `py/js/go/java/rb sql-injection`; BAN B608, B610, B611; GOS G201, G202, G701; BRK "SQL Injection"; SG | 8: T10 A05, C25 (#2), ASVS V1, CS, SCR, CRG, CERT IDS00-J, OSSF | https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html |
| OS command injection | `shell=True`, `exec`, `system`, backticks, `child_process.exec` with an interpolated string | 78, 77 | CQL `*/command-line-injection`; BAN B602-B607; GOS G204, G702; BRK "Command Injection"; ESL `detect-child-process` | 6: T10 A05, C25 (#9, #23), CS, SCR, CRG, ASVS V1 | https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html |
| Code injection / eval | `eval`, `exec`, `Function()`, dynamic `require`/`import`, `instance_eval`, `constantize` on input | 94, 95 | CQL `*/code-injection`; BAN B102, B307; ESL `detect-eval-with-expression`, `detect-non-literal-require`; BRK "Dangerous Evaluation", "Remote Code Execution" | 4: C25 (#10), T10 A05, SCR, CS | https://cwe.mitre.org/data/definitions/94.html |
| Server-side template injection | Outside input used as the template source rather than as template data | 1336 | CQL `java/server-side-template-injection`; GOS G708; BRK "Dynamic Render Paths" | 2: T10 A05, CS (Injection Prevention) | https://cwe.mitre.org/data/definitions/1336.html |
| LDAP, XPath, header/CRLF, SMTP, log injection | Input placed in LDAP filters, XPath, response headers, mail headers, log lines without encoding | 90, 643, 113, 93, 117 | CQL `*/log-injection` (go, java, js, py, rb); GOS G706, G707 | 4: T10 A05, CS (LDAP, Logging), SCR, ASVS V1 | https://cheatsheetseries.owasp.org/cheatsheets/LDAP_Injection_Prevention_Cheat_Sheet.html , https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html |
| XML external entities | XML parser on untrusted input with DTDs/external entities enabled | 611, 776 | CQL `*/xxe` (java, js, py, rb, cs, swift, cpp); BAN B313-B319 | 4: T10 A02 (maps 611, 776), CS, SCR, ASVS V1 | https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html |
| Missing or client-only validation | New request fields with no type, length, range or allowlist check on the server; validation only in front-end code | 20, 1284 | CQL CWE-20 queries (JS: incomplete URL/hostname checks, missing regexp anchor) | 6: C25 (#18), ASVS V2, CS, SCR, OSSF, SSDF PW.5.1 ("Validate all inputs") | https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html |
| ReDoS and unbounded input | Regex with nested quantifiers on input; `RegExp(userInput)`; unbounded body, multipart or decompression size | 1333, 400, 770 | CQL `*/redos`, `*/polynomial-redos`; ESL `detect-unsafe-regex`, `detect-non-literal-regexp`; GOS G110, G120 | 3: API4, C25 (#25), CS (DoS) | https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html |
| Prototype pollution (JS) | Recursive merge/clone or `obj[key] = value` with keys from input | 1321, 915 | CQL `js/prototype-pollution*`; ESL `detect-object-injection` (very noisy) | 1: CS | https://cheatsheetseries.owasp.org/cheatsheets/Prototype_Pollution_Prevention_Cheat_Sheet.html |
| Open redirect | Redirect target taken from a query param or header without an allowlist | 601 | CQL `*/url-redirection` (py, rb, js, go, java, cs); BRK "Unsafe Redirects"; GOS G710 | 2: CS, ASVS V3 | https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html |

### 2.5 Output encoding

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Cross-site scripting (reflected, stored, DOM) | `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `|safe`, `mark_safe`, `html_safe`, `raw`, `Markup()`, `autoescape=False`, `template.HTML(x)`; building HTML by concatenation | 79, 80 | CQL `js/xss`, `js/stored-xss`, `js/xss-through-dom`, `py/reflective-xss`, `rb/reflected-xss`; BAN B701-B704; GOS G203, G705; BRK XSS (3 types); ESL `detect-disable-mustache-escape` | 7: C25 (#1), T10 A05, ASVS V1/V3, CS, SCR, CRG, OSSF | https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html , https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html |
| Missing security headers / CSP weakened | CSP removed or `unsafe-inline` added; `X-Frame-Options`/frame-ancestors dropped | 693, 1021 | CQL `js/missing-x-frame-options`, `cs/web/missing-x-frame-options` | 3: T10 A02, ASVS V3, CS | https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html , https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html |

### 2.6 Secrets and configuration

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Secret committed to the repo | High-entropy literal, key-shaped string, `.env`, `*.pem`, `credentials.json`, connection string with password | 798, 312, 540 | gitleaks (`gitleaks git --log-opts=<range>`, `gitleaks dir`; `--baseline-path` for only new findings); trufflehog (`trufflehog git file://. --since-commit main --results=verified,unknown --fail`; live verification); BAN B105-B107; GOS G101; CQL CWE-798 queries | 5: T10 A02, CS, OSSF, SCR, ASVS V13 | https://github.com/gitleaks/gitleaks , https://github.com/trufflesecurity/trufflehog |
| Secret exposed at runtime | Secret in `ENV`/`ARG` in a Dockerfile, echoed in CI, serialised into JSON/YAML, sent to the browser bundle, printed in logs | 532, 312, 538 | CQL `actions/excessive-secrets-exposure`, `actions/secrets-in-artifacts`, `js/build-artifact-leak`, `*/clear-text-logging`; GOS G117 | 4: CS (Secrets, Logging), T10 A03 (environment-scoped secrets), OSSF | https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html |
| Not using the repo's secret manager | New code reads a secret from a file or env var where the repo already uses a vault/KMS/SSM client | n/a (convention) | Judgement | 2: CS ("centralize and standardize"), SSDF PW.4 | https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html |

### 2.7 Cryptography

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Broken or weak algorithm / mode | MD5, SHA-1 for integrity or signatures; DES, RC4, ECB; RSA < 2048; RSA without OAEP | 327, 328, 326 | CQL many (`*/weak-cryptographic-algorithm`, `py/weak-block-mode`, `java/rsa-without-oaep`); BAN B303-B305, B505; GOS G401, G403, G405, G406, G501-G507 | 5: T10 A04, ASVS V11, CS, SCR, CERT | https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html |
| Insecure randomness for security values | `Math.random`, Python `random`, `math/rand` for tokens, ids, nonces, reset codes | 330, 338 | CQL `*/insecure-randomness` (cs, go, java, js, py, rb); BAN B311; GOS G404; ESL `detect-pseudoRandomBytes` | 4: ASVS V11, CS (Session, JWT), SCR, OSSF | https://cwe.mitre.org/data/definitions/338.html |
| Hard-coded key or IV, nonce reuse; encryption without authentication | Literal key/IV; static nonce with GCM; CBC/CTR with no MAC | 321, 329, 323, 353 | GOS G407; CQL `cs/hard-coded-symmetric-encryption-key`, `swift/hardcoded-key`, `rust/hard-coded-cryptographic-value` | 3: SCR (correct IV/nonce use), CS, ASVS V11 | https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html |
| TLS verification disabled / weak TLS | `verify=False`, `rejectUnauthorized: false`, `InsecureSkipVerify: true`, custom trust-all TrustManager, `ssh.InsecureIgnoreHostKey` | 295, 297, 319 | CQL `py/request-without-cert-validation`, `js/disabling-certificate-validation`, `go/disabled-certificate-check`, `java/insecure-trustmanager`; BAN B501-B504, B507, B323; GOS G106, G402; BRK "SSL Verification Bypass" | 4: T10 A04, ASVS V12, CS, SCR | https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html |
| Hand-rolled crypto or security primitive | Custom cipher, custom token format, custom password hash instead of the platform library | 327, 1240 | Judgement | 3: SSDF PW.4, OSSF ("industry-standard libraries"), CS | https://csrc.nist.gov/pubs/sp/800/218/final |

### 2.8 File and path handling

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Path traversal | `open(base + name)`, `path.join(root, req.params.x)`, `send_file(user_path)`; prefix check without canonicalising (`startswith("/safedir")`) or without resolving symlinks | 22, 23, 59 | CQL `*/path-injection`; GOS G304, G703; BRK "Path Traversal", "File Access"; ESL `detect-non-literal-fs-filename` (noisy) | 6: C25 (#6), T10 A01, ASVS V5, CS, SCR, CRG | https://cwe.mitre.org/data/definitions/22.html |
| Archive extraction (zip slip, zip bomb) | `extractall`, `tar.extractall`, `zip.Open` loop writing entry names to disk | 22, 409 | CQL `*/zipslip`, `go/unsafe-unzip-symlink`; BAN B202 tarfile_unsafe_members; GOS G110, G305 | 3: CS (File Upload), ASVS V5, SCR | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html |
| Unrestricted upload | Upload handler trusting the client filename, extension or Content-Type; storing inside webroot; no size cap | 434, 646 | Judgement mostly | 4: C25 (#12), ASVS V5, CS, SCR | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html |
| Insecure permissions and temp files | `chmod 0777`, world-writable files, `mktemp`, fixed `/tmp/x` paths | 276, 732, 377 | BAN B103, B108, B306; GOS G301-G303, G306, G307 | 2: CERT, T10 A02 | https://raw.githubusercontent.com/securego/gosec/master/RULES.md |

### 2.9 Deserialisation

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Deserialising untrusted data with a native format | `pickle.load(s)`, `yaml.load` without SafeLoader, `jsonpickle.decode`, `torch.load` on downloads, Java `ObjectInputStream.readObject`, `XMLDecoder`, .NET `BinaryFormatter`, JSON.Net `TypeNameHandling`, PHP `unserialize`, Ruby `Marshal.load`/`YAML.load` | 502 | CQL `*/unsafe-deserialization` (cs, java, js, py, rb, rust); BAN B301, B302, B506, B614, B615; GOS G709; BRK "Unsafe Deserialization", "Remote Execution in YAML.load" | 6: C25 (#15), T10 A08, CS, SCR, ASVS V1/V15, CRG | https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html |

### 2.10 Server-side request forgery

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| SSRF | HTTP client, image/PDF renderer, webhook, URL preview or import that fetches a URL or host taken from input; validation by blocklist, by string match before DNS resolution, or with redirects still followed | 918 | CQL `py/full-ssrf`, `py/partial-ssrf`, `js/request-forgery`, `go/request-forgery`, `java/ssrf`, `rb/request-forgery`, `actions/request-forgery`; GOS G107, G704; BAN B310 (urlopen, coarse) | 5: C25 (#22), T10 A01 (now mapped there), API7, CS, ASVS V4/V12 | https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html |
| Unsafe consumption of third-party APIs | Data from a partner/upstream API used without validation, or followed redirects to it, as if trusted | 20, 918 | Judgement | 1: API10 | https://api-security.owasp.org/editions/2023/en/0x11-t10 |

### 2.11 Dependency and supply chain

| Class | Recognise in a diff | CWE | Tools (per ecosystem) | Sources | URLs |
|---|---|---|---|---|---|
| Known-vulnerable dependency | Manifest or lockfile change adding or bumping a package | 1395, 1035, 1104 | JS: `npm audit --audit-level=high --omit=dev` (https://docs.npmjs.com/cli/v10/commands/npm-audit). Python: `pip-audit` (PyPI advisory DB or `-s osv`, https://github.com/pypa/pip-audit). Go: `govulncheck ./...` reports only vulnerable functions the code can reach (https://go.dev/doc/security/vuln/). Rust: `cargo audit` against RustSec (https://github.com/rustsec/rustsec/tree/main/cargo-audit). Ruby: `bundle-audit` against ruby-advisory-db, also flags http/git gem sources (https://github.com/rubysec/bundler-audit). Any lockfile: `osv-scanner` on OSV.dev (https://google.github.io/osv-scanner/). Rails: BRK "Unmaintained Dependencies" | 5: T10 A03, CS, SSDF PW.4/RV.1, OSSF, SCR ("dependency currency") | https://top10.owasp.org/2025/A03_2025-Software_Supply_Chain_Failures/ , https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html |
| Hallucinated, typosquatted or untrusted package | New dependency name that is new to the registry, low-download, a near-miss of a popular name, or absent from the registry | 1357, 829 | `npm audit signatures` checks registry signatures and provenance (npm docs above); existence/age check against the registry is manual or scripted | 3: T10 A03 ("official (trusted) sources"), OSSF ("independently check new dependencies"), CS (Supply Chain) | https://arxiv.org/abs/2406.10279 , https://cheatsheetseries.owasp.org/cheatsheets/Software_Supply_Chain_Security_Cheat_Sheet.html |
| CI/CD workflow weaknesses | `.github/workflows` changes: `pull_request_target` checking out PR head, unpinned third-party actions, `${{ github.event.* }}` in `run:`, broad `permissions:` | 829, 94 | CQL `actions/untrusted-checkout/*`, `actions/unpinned-tag`, `actions/artifact-poisoning/*`, `actions/excessive-secrets-exposure` | 3: T10 A03 (CI/CD hardening), CS (CI/CD), SSDF PO.3/PS.1 | https://cheatsheetseries.owasp.org/cheatsheets/CI_CD_Security_Cheat_Sheet.html |
| Code fetched from untrusted source at runtime | `curl | sh`, script tags from third-party CDNs without integrity, downloads over http | 494, 829 | CQL `js/functionality-from-untrusted-source`, `js/insecure-download`, `rb/insecure-download`, `java/maven/non-https-url` | 2: T10 A08, CS | https://top10.owasp.org/2025 |

### 2.12 Logging and error disclosure

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Sensitive data in logs | Logging request bodies, headers, tokens, passwords, session ids, connection strings, PII | 532, 312 | CQL `*/clear-text-logging*` (go, js, py, rb, rust, swift), `java/sensitive-log` | 4: CS (Logging), T10 A09, OSSF, SCR | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html |
| Stack traces / internals in responses | Exception message, SQL error, stack trace, or debug page returned to the client | 209, 550, 215 | CQL `*/stack-trace-exposure`, `java/error-message-exposure`; BRK "Information Disclosure" | 5: T10 A10 (maps 209, 550, 215), T10 A02, CS (Error Handling), SCR, OSSF | https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html |
| Security events not logged | New auth, authorisation-failure or admin paths with no audit log entry | 778, 223 | Judgement | 4: T10 A09, ASVS V16, CS (Logging), SCR | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html |
| Failing open / swallowed errors | `except: pass`, empty catch around an auth or validation call, unchecked error return, default-allow on exception | 636, 252, 390, 391 | BAN B110, B112; GOS G104 | 3: T10 A10, CS (Authorization: fail safely), CERT | https://top10.owasp.org/2025/A10_2025-Mishandling_of_Exceptional_Conditions/ |

### 2.13 Unsafe defaults

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Debug mode or dev tooling on in shipped config | `DEBUG=True`, Flask `debug=True`, exposed pprof, actuator or GraphQL introspection in production config | 489, 215 | BAN B201; GOS G108 | 3: T10 A02 (maps 489), API8, SSDF PW.9 | https://top10.owasp.org/2025/A02_2025-Security_Misconfiguration/ |
| Binding to all interfaces / exposed service | `0.0.0.0` listener, new port in compose/k8s exposed publicly, admin port public | 1327 | BAN B104; GOS G102 | 2: T10 A02 (unneeded ports and services), SSDF PW.9 | https://cwe.mitre.org/data/definitions/1327.html |
| Insecure defaults shipped to end users | New config option whose default is the insecure choice (auth off, TLS off, permissive CORS, open signup) | 1188, 453 | Judgement | 3: SSDF PW.9.1 ("default settings are secure"), OSSF ("Prefer safe defaults"), T10 A02 | https://csrc.nist.gov/pubs/sp/800/218/final |
| HTTP server without timeouts | `http.ListenAndServe` without `ReadHeaderTimeout`; client requests without timeout | 400 | GOS G112, G114; BAN B113 | 2: API4, CS (DoS) | https://raw.githubusercontent.com/securego/gosec/master/RULES.md |
| Containers running as root, unpinned base images | Dockerfile with no `USER`, `:latest` base image | 250, 1357 | Judgement (hadolint not researched here) | 2: OSSF, CS (Docker) | https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html |

### 2.14 Concurrency and race conditions that matter for security

| Class | Recognise in a diff | CWE | Tools | Sources | URLs |
|---|---|---|---|---|---|
| Check-then-act on shared state (double spend, coupon reuse, limit bypass) | Read balance/count/status, then write in a separate statement with no transaction, row lock, unique constraint or atomic update | 362, 367, 841 | Judgement | 3: SCR (race conditions, transaction atomicity), API6, CRG | https://cheatsheetseries.owasp.org/cheatsheets/Secure_Code_Review_Cheat_Sheet.html |
| Filesystem TOCTOU | `exists()`/`stat()` then `open()`; symlink check then use; walk callbacks that act on paths | 367, 59 | GOS G122; CERT FIO45-C (C), POS35-C | 2: CERT, SCR | https://wiki.sei.cmu.edu/confluence/display/c/FIO45-C.+Avoid+TOCTOU+race+conditions+while+accessing+files |
| Authorisation decided on stale state | Permission cached across a role change; token valid after revoke because the check reads a cache | 613, 362 | Judgement | 2: ASVS V7/V8, CS (Session: revoke every id) | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html |

---

## 3. What AI-written code is reported to get wrong more often

| Finding | Evidence | URL |
|---|---|---|
| About 40% of Copilot completions in security-relevant scenarios were vulnerable | Pearce et al., IEEE S&P 2022: 1,689 programs, 89 scenarios built around CWE Top 25 classes | https://arxiv.org/abs/2108.09293 |
| Participants with an assistant wrote less secure code and were more confident in it | Perry et al., CCS 2023. Largest gaps: SQL built by string concatenation (36% insecure vs 7% control), unsafe randomness in ECDSA signing (3% secure vs 21%), path sandbox without canonicalising or resolving symlinks (12% secure vs 29%), trivial ciphers and no ciphertext authentication | https://arxiv.org/abs/2211.03622 , https://arxiv.org/html/2211.03622 |
| Counter-evidence: small effect in low-level C | Sandoval et al., USENIX Security 2023, N=58: assisted group's security-critical bug rate no more than 10% higher than control | https://www.usenix.org/conference/usenixsecurity23/presentation/sandoval |
| In real GitHub projects: 29.5% of Python and 24.2% of JS AI snippets had weaknesses; CWE-330 insufficient randomness, CWE-94 code injection, CWE-79 XSS stood out | Fu et al., ACM TOSEM, 733 snippets from Copilot, CodeWhisperer, Codeium; 43 CWEs | https://arxiv.org/abs/2310.02059 |
| Models picked the insecure option in 45% of tasks; XSS (CWE-80) failed 86%, log injection (CWE-117) 88%; Java worst (> 70%); bigger models no better | Veracode 2025 GenAI Code Security Report (vendor), 80 tasks, 100+ models; Spring 2026 update says little changed | https://www.veracode.com/press-release/ai-generated-code-poses-major-security-risks-in-nearly-half-of-all-development-tasks-veracode-research-reveals/ , https://veracode.com/blog/spring-2026-genai-code-security |
| About half of functionally correct backends were exploitable; best model (o1) 62% correct | BaxBench (ETH Zurich, ICML 2025): 392 tasks, 14 frameworks, 6 languages, expert-written exploits | https://arxiv.org/abs/2502.11844 |
| Package hallucination: 5.2% (commercial) and 21.7% (open models) of suggested packages did not exist; 205,474 unique fake names; names repeat across runs, which makes "slopsquatting" practical | Spracklen et al., USENIX Security 2025; press coverage notes no confirmed in-the-wild case at the time | https://arxiv.org/abs/2406.10279 , https://www.csoonline.com/article/3961304/ai-hallucinations-lead-to-new-cyber-threat-slopsquatting.html |
| Secrets: Copilot-active repos leaked at least one secret in 6.4% vs 4.6% of all public repos; the 2026 edition says AI-co-authored commits were about twice as likely to leak | GitGuardian State of Secrets Sprawl 2025 (vendor), and SC World coverage of the 2026 edition | https://www.gitguardian.com/state-of-secrets-sprawl-report-2025 , https://www.scworld.com/news/ai-coding-assistants-twice-as-likely-to-leak-secrets-as-overall-leaks-rise-34 |
| Fewer syntax and logic bugs, but privilege-escalation paths up 322% and architectural design flaws up 153%; cloud keys exposed about twice as often | Apiiro (vendor), Sept 2025, Fortune-50 repositories. Primary page was read only through search results; The Register coverage confirms the figures | https://apiiro.com/blog/4x-velocity-10x-vulnerabilities , https://www.theregister.com/2025/09/05/ai_code_assistants_security_problems/ |
| Iterating with the model made security worse: 37.6% more critical vulnerabilities after five refinement rounds | Shukla, Joshi, Syed 2025, 400 samples, 40 rounds | https://arxiv.org/abs/2506.11022 |
| Roughly half of snippets from five LLMs contained bugs that could be exploited; policy review of the risks | CSET Georgetown, Nov 2024 (figures as reported in its key takeaways) | https://cset.georgetown.edu/publication/cybersecurity-risks-of-ai-generated-code/ |

**What this means for the reviewer.** The research keeps pointing at the same classes, the ones where the
safe version takes one more deliberate step:

1. **Injection and output encoding**: SQL built from strings, XSS, log injection (Perry, Fu, Veracode).
2. **Insecure randomness and weak crypto**: CWE-330/338, trivial ciphers, unauthenticated encryption
   (Perry, Fu).
3. **Path handling without canonicalisation** (Perry).
4. **Code injection / eval** (Fu).
5. **Missing or wrong authorisation, privilege escalation, design-level flaws** (Apiiro, BaxBench); these are
   the ones tools miss.
6. **Hard-coded secrets** (GitGuardian, Apiiro).
7. **Dependencies that do not exist or are not the intended package** (Spracklen).

Iterating without review makes things worse (Shukla). Telling the model to "act as a security expert" is
not recommended by OpenSSF, which reports experiments showed it does not help; OpenSSF suggests a
critique-and-improve loop backed by linters, SAST and dependency checkers instead (OSSF).

---

## 4. What the reviewer agent needs

### 4.1 When it runs: diff signals

The sources agree that review effort should follow risk (CRG 6.5; SCR "prioritise high-risk modifications
and changes that affect security controls"). Run the security reviewer when the diff matches any of
these. Each comes from a catalogue row above.

- **Paths and names**: `auth`, `login`, `session`, `token`, `jwt`, `oauth`, `password`, `permission`, `role`,
  `policy`, `acl`, `admin`, `middleware`, `guard`, `crypto`, `secret`, `upload`, `webhook`, `callback`.
- **New or changed entry points**: routes, controllers, handlers, RPC/GraphQL resolvers, CLI commands that
  take outside input, message consumers.
- **Sinks**: SQL/ORM raw queries, subprocess/exec/eval, template rendering of strings, filesystem paths built
  from variables, archive extraction, outbound HTTP with a variable URL, deserialisers, redirects, HTML
  escape hatches (the identifiers listed in 2.4, 2.5, 2.8, 2.9, 2.10).
- **Security libraries**: imports of crypto, hashing, JWT, TLS, random, or auth packages.
- **Config and infrastructure**: `.env*`, settings files, Dockerfile, compose/k8s manifests, CORS, cookie or
  session settings, security headers, `.github/workflows/*`.
- **Dependencies**: any manifest or lockfile change (`package.json`, `requirements*.txt`, `pyproject.toml`,
  `go.mod`, `Cargo.toml`, `Gemfile`, lockfiles).
- **Any secret-scanner hit** in the diff, whatever the file.
- **Plan marking**: the plan already sends security-sensitive tasks to `implementer-hard`; the same flag
  should trigger this reviewer.

Skip it for docs-only, test-only (unless tests weaken auth fixtures in shared config) and pure refactors
with no sink or entry-point change.

### 4.2 Inputs

1. The task diff and its acceptance criteria (the same inputs `review-correct` gets; never the implementer's
   conversation).
2. **The repo's security architecture map**, gathered once by the explorer and cached: where auth is
   enforced (middleware, decorators, router groups, policy objects), the validation layer (schemas, DTOs,
   serializers), the output-encoding default (template auto-escaping), the secret source (vault/KMS/SSM/
   env), the HTTP client wrapper (SSRF guard), the logger (redaction), and the ORM. See 4.6.
3. The call sites around each changed sink and entry point (one hop in and out), because most security
   findings need the source-to-sink trace (CRG "source to sink analysis").
4. Output from whichever tools are installed (4.3), restricted to lines the diff touches.
5. The language/framework list, to choose tools and to know which framework defaults already protect
   (auto-escaping, ORM parameterisation, CSRF middleware).

**Prompt-injection note.** The diff is untrusted input to the reviewer. Anthropic's own diff reviewer states it
"is not hardened against prompt injection attacks and should only be used to review trusted PRs"
(https://github.com/anthropics/claude-code-security-review). Comments or strings in the diff that address the
reviewer are data, and a diff that contains them is itself worth flagging.

### 4.3 Mechanical checks (run when installed) versus judgement

Run only what is on the machine; never install during review. Scan the base and head, or use the tool's
baseline feature, so only findings the diff introduced are reported.

| Language / area | Command | Notes |
|---|---|---|
| All: secrets | `gitleaks git --log-opts="<base>..HEAD"` or `gitleaks dir <paths>`; `--baseline-path` for only new findings | Exit 1 on leaks; `gitleaks:allow` and `.gitleaksignore` exist, so a suppression added in the diff is itself a finding. https://github.com/gitleaks/gitleaks |
| All: secrets, verified | `trufflehog git file://. --since-commit <base> --branch HEAD --results=verified,unknown --fail` | Verified means live credential: always blocking. https://github.com/trufflesecurity/trufflehog |
| All: SAST | `semgrep --config p/owasp-top-ten <changed files>` (or the repo's own rules) | CE is single-function only; cross-file needs Pro. `nosemgrep: <rule-id>` suppressions should carry a reason. https://docs.semgrep.dev/semgrep-pro-vs-oss , https://semgrep.dev/docs/ignoring-files-folders-code |
| All: SAST, deep | CodeQL `security-extended` suite, if a database can be built in time | Widest CWE coverage of any free tool (CQL); slow to build. |
| Python | `bandit -r <changed files>` | Reports severity and confidence per issue. |
| Go | `gosec -fmt sarif ./...`; `govulncheck ./...` | gosec maps every rule to a CWE and supports `-nosec-require-justification`; govulncheck reports only reachable vulnerable functions. |
| Ruby/Rails | `brakeman`; `bundle-audit check --update` | Brakeman confidence High/Medium/Weak. |
| JS/TS | `eslint` with `eslint-plugin-security`; `npm audit --audit-level=high --omit=dev`; `npm audit signatures` | The plugin's README warns it is noisy: treat as hints, never as findings alone. |
| Rust | `cargo audit` | RustSec DB. |
| Any lockfile | `osv-scanner` | OSV.dev. |

**Judgement only (no tool does it reliably):** missing or incorrect authorisation, IDOR/BOLA, property-level
exposure, business-flow abuse, race conditions on shared state, session lifecycle, JWT and OAuth flow
correctness, insecure defaults in new options, whether the diff bypasses the repo's existing control,
failing open. These are the classes SCR and CRG reserve for manual review, and the classes where AI code
regresses most (Apiiro, BaxBench). The reviewer should spend most of its effort here and let the tools
cover the pattern-shaped classes.

### 4.4 Keeping false positives low

All the sources admit tools over-report (CRG, SCR, Brakeman, eslint-plugin-security). Practices that the
sources and tools support:

1. **Require a concrete trace.** A finding names the source (where outside data enters), the sink, the
   file:line of each, and why no existing control in between stops it (CRG source-to-sink; SCR trust
   boundaries). No trace, no finding: at most a question.
2. **Check the framework and repo defaults first.** ORM parameterisation, template auto-escaping, global auth
   middleware and CSRF middleware make many pattern hits harmless. Brakeman's own confidence levels turn on
   whether the value is outside input (https://brakemanscanner.org/docs/confidence/).
3. **Report only what the diff introduced.** Use baselines (gitleaks `--baseline-path`) or base-vs-head
   comparison; pre-existing issues go in a separate non-blocking note.
4. **Use the tools' own confidence signals**: trufflehog verified status, govulncheck reachability, Brakeman
   and Bandit confidence. Drop low-confidence tool hits unless the reviewer confirms them by trace.
5. **A default exclusion list, adjustable per repo.** Anthropic's diff reviewer excludes DoS, rate limiting,
   resource exhaustion, generic input validation without proven impact, and open redirects by default, and
   lets the repo change that list (https://github.com/anthropics/claude-code-security-review). Section 1
   shows C25 and the API list disagree on DoS. Suggested middle course: report these only when the diff
   touches an authentication, reset, OTP or payment endpoint (for rate limits), or an auth redirect such as
   OAuth `redirect_uri` or a post-login `next=` parameter (for open redirects), and otherwise leave them out.
6. **Suppressions need a reason.** gosec can enforce `-nosec-require-justification`; Semgrep keeps suppressed
   findings as "Ignored". A new suppression comment in the diff (`nosec`, `nosemgrep`, `gitleaks:allow`,
   `trufflehog:ignore`, `# noqa: S...`) with no reason is a finding.
7. **Ask rather than assert when the control may live outside the diff.** Phrase it as a question naming the
   file to check, so the implementer can answer in one line.

### 4.5 Rating severity

Use a recognised scheme with few inputs that a reviewer can defend from the diff alone. The **OWASP Risk
Rating Methodology** fits: likelihood (threat agent and vulnerability factors) and impact (technical and
business), each LOW/MEDIUM/HIGH, combined in a fixed matrix to Note/Low/Medium/High/Critical
(https://community.owasp.org/OWASP_Risk_Rating_Methodology):

| Impact \ Likelihood | Low | Medium | High |
|---|---|---|---|
| High | Medium | High | Critical |
| Medium | Low | Medium | High |
| Low | Note | Low | Medium |

For Critical and High findings, also attach a **CVSS 4.0 base vector (CVSS-B)**, the scheme NVD and most
scanners use, so findings can be compared with advisories. CVSS 4.0 (Nov 2023) bands: Low 0.1-3.9,
Medium 4.0-6.9, High 7.0-8.9, Critical 9.0-10.0; a score from base metrics only is labelled CVSS-B
(https://www.first.org/cvss/v4.0/specification-document). Carry the CWE id on every finding.

Suggested mapping to idleflow verdicts: Critical and High block the task (retry); Medium blocks unless the
plan explicitly accepts it; Low and Note are non-blocking notes. Always blocking whatever the matrix says: a
verified live secret, authentication or authorisation removed from an existing endpoint, TLS verification
disabled in non-test code.

CERT's priority scheme (severity x likelihood x remediation cost giving L1-L3) is meant for prioritising
conformance with a coding standard on existing code, and its own wiki says new code is assumed to conform
to the whole standard (search-result reading of https://wiki.sei.cmu.edu/confluence/display/java/Rule%3A+Priority+and+Levels).
It does not fit diff review.

### 4.6 Treating the repo's security architecture as the convention

The sources say to build security controls once, centrally, and reuse them: T10 A01 ("implement access
control mechanisms once and re-use them throughout the application" and "use established toolkits or
patterns with declarative access controls"), Authorization CS ("centralize the logic"), Secrets CS
("centralize and standardize"), SSDF PW.4 (reuse well-secured software, especially security
functionality). For the reviewer that means:

1. **Discover the controls first.** As part of the architecture map in 4.2: the auth middleware or decorator
   and how routes opt in or out; the permission/policy layer; the validation layer (pydantic/zod/DTOs/
   serializers/strong params); the output encoder; the secret client; the outbound HTTP wrapper; the
   logger's redaction; the ORM and any sanctioned raw-query helper.
2. **Bypassing a control is a finding even when the new code is safe in isolation.** A handler that checks a
   role by hand where the repo uses a policy object, a raw `requests.get` where the repo has an
   SSRF-guarded client, or `os.environ["KEY"]` where the repo uses its vault client, splits the security
   model and will drift. Severity follows what the bypass exposes; when the bypass itself is correct, flag
   it as a conformance issue for `review-conform` to own.
3. **Changes to the control itself get the deepest review.** A diff that edits the auth middleware,
   the policy layer, the validation base class or the secret loader affects every caller. Treat it as a
   baseline-review trigger in SCR's sense and trace the effect on existing routes.
4. **Do not recommend a different architecture.** If the repo uses session cookies, do not push JWTs, and the
   reverse. Judge against the repo's own pattern and the matching ASVS chapter; propose architectural
   changes only as a non-blocking note.
5. **Where the repo has no control for a class the diff needs**, say so once, name the established library
   for the stack, and leave the choice to the plan (idleflow's library-scout exists for this).
6. **Record what was learned.** SSDF PW.7.2 examples 7 and 8 and RV.3 ask that root causes and lessons from
   review be recorded where developers can find them; idleflow's lessons file serves this, so a repeated
   class of finding should become a lesson rather than a repeated comment.

### 4.7 Output shape (suggested)

One finding per issue: class and CWE, file:line of source and sink, the trace, which existing control is
missing or bypassed, severity (OWASP RR, plus CVSS-B for High/Critical), confidence (confirmed by trace /
tool-only / question), a fix that names the repo's own control, and which tool, if any, also flagged it.
This mirrors the fields Anthropic's reviewer produces (explanation, severity, remediation,
https://github.com/anthropics/claude-code-security-review) and SSDF PW.7.2's "record and triage all
discovered issues and recommended remediations".
