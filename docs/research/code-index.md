# Semantic (embedding) code search for coding agents: options, evidence, and what idleflow needs

Researched 2026-11-25. Star counts, licences, last-push dates and latest releases come from the GitHub REST API (`gh api repos/<owner>/<repo>` and `.../releases/latest`) on that date; the repository URL is given for each. Other facts carry their own URL.

## Summary

- Several mature local-first tools now give Claude Code semantic search with a local embedding model and a local index, with no account and no code leaving the machine: **ck** (Rust, FastEmbed models, hybrid BM25 + vectors, CLI and MCP), **ColGREP** (Rust, LightOn's late-interaction models on CPU, grep-shaped CLI plus Claude Code hooks), **cocoindex-code** (Python, local sentence-transformers in its `full` install, Claude Code plugin/skill/MCP), **osgrep** (local ONNX fork of mgrep), and **SeaGOAT** (local ChromaDB, CLI only). **grepai**, **ChunkHound** and **open-codebase-index** are local when paired with Ollama.
- The best-known option, **Claude Context** (Zilliz, 12.7k stars), is not local by default: its documented setup uses an OpenAI key and Zilliz Cloud. Ollama is supported for embeddings, but it still needs a Milvus server.
- Hosted options are **Augment Context Engine MCP** (account, per-query billing), **Sourcegraph MCP** (`nls_search`, Enterprise plans only) and **mgrep** (uploads every file to a Mixedbread cloud store). All three send code or queries to an outside service.
- The evidence is mixed. Cursor (vendor) reports +12.5% average answer accuracy with semantic search plus grep over grep alone, and a bigger retention effect on repos of 1,000 or more files. Independent 2026 papers find that agents mostly ignore semantic tools when grep is available. On a fair benchmark, BM25 matches dense retrieval once the query contains the code's identifiers, and swapping the search tool moves agent localization far less than swapping the model. Semantic search helps most on concept queries that name no identifier, on noisy repos where grep returns many false positives, and for small models.
- Vendor token-saving claims (Claude Context about 40%, mgrep about 2x, ColGREP 56% fewer search operations, cocoindex-code 70%) are self-reported, mostly on question answering, and none is independently replicated.
- **Recommendation: offer `ck` as the local-first default**, with ColGREP as the named alternative. ck is permissively licensed (MIT or Apache-2.0), is one binary with no server, account or Python, runs offline, fuses BM25 with vectors (which is what the independent evidence recommends), and exposes both a CLI with JSON output and an MCP server with an `index_status` tool. Semantic search should be an addition to grep and the structural map, never a replacement.

## The options

### Local-first (local model, local index)

**ck** (BeaconBay/ck), https://github.com/BeaconBay/ck
- What: a "semantic grep" in Rust with regex, semantic (`--sem`) and hybrid BM25 + semantic (`--hybrid`) modes, using grep-like flags (https://github.com/BeaconBay/ck).
- Licence: dual Apache-2.0 or MIT (README); the GitHub API reports Apache-2.0. 1,772 stars, release 0.8.1 on 2026-10-11, last push 2026-11-05.
- Claude Code: `claude mcp add ck-search -s user -- ck --serve`. MCP tools are `semantic_search`, `regex_search`, `hybrid_search`, `index_status`, `reindex` and `health_check`. As a CLI it gives `--json` / `--jsonl` output, `--topk` and `--threshold` (README).
- Models: FastEmbed, run locally. The default is BGE-Small; mxbai-xsmall, nomic-v1.5 and jina-code are options (`ck --index --model ...`). The README FAQ says it is "completely offline. The embedding model runs locally with no network calls" once the model has been downloaded and cached.
- Index: `.ck/` beside the code (`embeddings.json`, `ann_index.bin`, `tantivy_index/`), or under `$CK_INDEX_DIR`. The README gives the size as "~2x source code size with compression" in one place and "1-3x" in the FAQ. It claims about 1M LOC indexed in under 2 minutes and sub-500 ms queries; these are README claims with no published benchmark.
- Freshness: semantic and hybrid searches refresh the index before they run. Chunks are hashed with blake3, so only changed chunks are re-embedded, with 80-90% cache hits claimed on typical changes. Interrupted indexing resumes. Commands: `ck --status .`, `ck --clean .`, `ck --add <file>`. There is no watcher.
- Languages: tree-sitter chunking for Python, JS/TS, Rust, Go, C, C++, Ruby, Haskell, C#, Dart, Zig and Markdown. Everything else is indexed as plain text. Java, PHP and Swift chunkers are on the roadmap.
- Limits: Rust 1.88+ to build from source. MCP search returns 100 results by default. It respects `.gitignore` and writes its own `.ckignore`.

**ColGREP** (in lightonai/next-plaid), https://github.com/lightonai/next-plaid/blob/main/colgrep/README.md
- What: a "stronger grep" with semantic ranking and hybrid regex + semantic queries, built on late-interaction (ColBERT-style) models (https://blog.lighton.ai/blog-posts/lateon-code-colgrep-lighton-unveils-state-of-the-art-code-retrieval-models-and-code-search-tooling).
- Licence: Apache-2.0. The next-plaid repo has 624 stars, release v1.8.5 on 2026-10-10, last push 2026-10-10.
- Claude Code: `colgrep --install-claude-code` installs hooks ("full hooks support"). It has a CLI with `--json` and an `--agent` mode, where a local roughly 2.5 GB model explores the code and returns locations. No MCP server is documented.
- Models: the default is `lightonai/LateOn-Code-edge` (17M parameters), run on CPU through ONNX Runtime with int8 quantization. The larger LateOn-Code has 130M or 149M parameters (the blog gives both figures). Everything runs locally.
- Index: outside the repo, under `~/.local/share/colgrep/indices/{project}-{hash8}/` on Linux: a PLAID index, SQLite metadata, and `state.json` with file hashes. Multi-vector storage is larger than single-vector storage, which it offsets with quantization and memory-mapping. No size or build-time figures are published.
- Freshness: each search checks for changed files and updates the index first. Deleted files are pruned, and desync after an interrupted run is repaired automatically. `colgrep status` and `colgrep clear` are provided.
- Languages: tree-sitter extraction for about 24 languages, including Python, TS/JS, Go, Rust, Java, C/C++, Ruby, C#, Kotlin, Swift, Scala, PHP, SQL, Vue and Svelte, plus document-style units for Markdown, YAML, JSON, shell and more.
- Evidence: LightOn's own Claude Code test used 135 Q&A questions with Opus 4.5. The judge preferred ColGREP answers 70% of the time, and ColGREP used 56% fewer search operations and averaged 15.7% fewer tokens. LightOn's caveats: Q&A only, LLM judge, caching ignored, and one repository (TRL) where the baseline won.

**cocoindex-code**, https://github.com/cocoindex-io/cocoindex-code
- Licence: Apache-2.0. 2,991 stars, release v0.2.43 on 2026-11-05, last push 2026-11-24.
- Claude Code: plugin (`/plugin marketplace add cocoindex-io/cocoindex-code`), skill (`npx skills add cocoindex-io/cocoindex-code`), or MCP (`claude mcp add cocoindex-code -- ccc mcp`). The CLI has `ccc index`, `ccc search`, `ccc status` and `ccc doctor`.
- Models: the `full` install bundles sentence-transformers with the default Snowflake/snowflake-arctic-embed-xs, run locally (about 1 GB of torch). The slim install goes through LiteLLM to cloud providers (OpenAI, Voyage, Gemini and others) or Ollama. Changing the model means re-indexing.
- Index: embedded, in `<project>/.cocoindex_code/` (SQLite plus LMDB with a 4 GiB default map). Large repos can hit `MDB_MAP_FULL` and need `COCOINDEX_LMDB_MAP_SIZE` raised.
- Freshness: incremental. A daemon keeps the model loaded, and the MCP `search` refreshes the index by default.
- Languages: about 30.
- Privacy: usage telemetry is on by default (it says no code, paths or queries are sent). Opt out with `COCOINDEX_DISABLE_USAGE_TRACKING=1`. It claims "70% token savings" with no method given.

**osgrep**, https://github.com/Ryandonofrio3/osgrep
- An Apache-2.0 fork of mgrep that embeds locally with `onnxruntime-node` (about 150 MB of models). 1,152 stars, release v0.5.16 on 2025-12-09, last push 2026-01-17, so it has gone quiet.
- Indexes live under `~/.osgrep/data`. `osgrep serve` watches files and re-indexes incrementally. `osgrep install-claude-code` adds plugin hooks that start and stop the server with the session.
- About 15 tree-sitter languages; unsupported files are skipped unless you pass `--allow-fallback`. It claims about 20% token savings with no method. Its troubleshooting notes mention stale and stuck indexes.

**SeaGOAT**, https://github.com/kantord/SeaGOAT
- MIT. 1,320 stars, release v1.6.1 on 2026-10-25, last push 2026-11-23.
- Local ChromaDB with its default local embedding engine, plus ripgrep for regex. Needs a running `seagoat-server`. CLI only; no MCP is documented.
- A hard-coded list of 12 languages. Indexing is throttled and "can take a long time" on large repos, and queries made before indexing finishes come with a warning. Tested on Linux.

**claude-context-local**, https://github.com/FarhanAliRaza/claude-context-local
- README says GPL-3.0 (GitHub detects no licence file). 238 stars, release v0.1 on 2025-09-06, last push 2025-11-13. Beta.
- Local google/embeddinggemma-300m (a 1.2-1.3 GB download that may need Hugging Face terms accepted), FAISS index, Merkle-DAG change detection. MCP via `claude mcp add code-search ...`. Python 3.12+. No size or time figures. Low activity.

### Local when paired with Ollama (or another local endpoint)

**grepai**, https://github.com/yoanbernabeu/grepai
- MIT. 1,954 stars, release v1.2.0 on 2026-10-30, last push 2026-11-02.
- Ollama (`nomic-embed-text`) is the default; LM Studio and OpenAI are also supported. Storage is a local GOB file (`.grepai/index.gob`, loaded into RAM, no concurrent access), PostgreSQL/pgvector, or Qdrant (https://yoanbernabeu.github.io/grepai/backends/stores). `grepai watch` keeps the index fresh. MCP: `claude mcp add grepai -- grepai mcp-serve` (https://yoanbernabeu.github.io/grepai/workspace). It also does call-graph tracing. No regex mode, no published benchmarks, and outside pull requests are not accepted.

**ChunkHound**, https://github.com/chunkhound/chunkhound
- MIT. 1,464 stars, release v6.2.0 on 2026-11-23, last push 2026-11-24.
- Embeddings from VoyageAI (recommended), OpenAI or Ollama (local). Local DuckDB storage (https://chunkhound.github.io/configuration). As an MCP server it watches files and updates the index as you edit (https://chunkhound.github.io/tutorial). Regex search works with no provider configured. It reports researching codebases of up to 180 million lines on one laptop, with no index size given. "Deep research" also needs an LLM provider. Python 3.10+.

**open-codebase-index**, https://github.com/Helweg/open-codebase-index
- MIT. 235 stars, release v0.40.1 on 2026-11-19, last push 2026-11-24.
- Rust plus tree-sitter, with embeddings, BM25, symbol lookup and a call graph. Embeddings come from Ollama (local) or OpenAI, Google or a custom endpoint. Storage is SQLite plus usearch, kept under `.claude/` for Claude Code. It has a watcher (`watchFiles`), git-aware incremental updates and branch scoping. Claude Code marketplace plugin. Needs Node 22.22+ and Rust to build. About 25 languages.

**Claude Context** (Zilliz), https://github.com/zilliztech/claude-context
- MIT. 12,724 stars, no GitHub releases (npm `@zilliz/claude-context-mcp@latest`), last push 2026-11-24.
- The documented install is `claude mcp add claude-context -e OPENAI_API_KEY=... -e MILVUS_ADDRESS=<zilliz-cloud-endpoint> -e MILVUS_TOKEN=... -- npx @zilliz/claude-context-mcp@latest`. Embeddings from OpenAI, VoyageAI, Gemini or Ollama. It needs a Milvus or Zilliz Cloud vector database. Hybrid BM25 + dense search, AST chunking, and Merkle-tree incremental re-index of changed files, with no watcher. 14 languages. Tools: `index_codebase`, `search_code`, `clear_index`, `get_indexing_status`.
- Its own evaluation (https://github.com/zilliztech/claude-context/tree/master/evaluation) ran 30 SWE-bench Verified tasks with GPT-4o-mini, 3 runs each. Retrieval F1 was unchanged (0.40 vs 0.40); tokens fell 39.4% (73,373 to 44,449) and tool calls fell from 8.3 to 5.3.

**Editor-bound indexes (not usable from Claude Code)**: Roo Code's codebase indexing (Qdrant with Ollama or OpenAI embeddings, https://docs.roocode.com/features/codebase-indexing), whose repository GitHub reports as archived (last push 2026-05-15, https://github.com/RooCodeInc/Roo-Code), and Kilo Code's indexing (Ollama with LanceDB stays local, https://kilo.ai/docs/customize/context/codebase-indexing). Both live inside their own extensions, so they matter only as design references.

### Hosted

**Augment Context Engine MCP**, https://docs.augmentcode.com/context-services/mcp/overview.md
- Local mode runs the Auggie CLI as a stdio MCP server that indexes the working directory in real time. Remote mode indexes the default branches of repos connected through the Augment GitHub App on Augment's infrastructure, and re-indexes on push. Both need an Augment account. Billing is LLM tokens at list price plus a 40% service fee, about $0.03-0.06 per query. The docs do not say where local-mode embedding happens, so treat both modes as sending code to Augment.
- Vendor benchmark (https://augmentcode.com/product/context-engine-mcp): 300 Elasticsearch PRs with 3 prompts each, scored on correctness, completeness and similar. It reports "+80%" for Claude Code + Opus 4.6 but states no baseline. The engine is closed source.

**Sourcegraph MCP**, https://sourcegraph.com/docs/api/mcp
- 16 tools, including `keyword_search`, `nls_search` ("semantic search with flexible linguistic matching", only on the `/.api/mcp/all` endpoint), `go_to_definition`, `find_references` and `deepsearch`. Enterprise plans only, run against your Sourcegraph instance, which can be self-hosted. Sourcegraph itself removed embeddings from Cody in September 2024, saying "we have replaced them with Sourcegraph Search" (https://patch-diff.githubusercontent.com/raw/sourcegraph/docs/pull/672.patch).

**mgrep** (Mixedbread), https://github.com/mixedbread-ai/mgrep
- Apache-2.0 client. 4,443 stars, release v0.1.13 on 2026-04-25, which is also the last push. "Every file is pushed into a Mixedbread Store" in the cloud. `mgrep watch` keeps it synced, and `mgrep install-claude-code` adds the plugin. Default limits are 1 MB per file and 1,000 files per sync, which is too small for a 100k-line repo without changing the settings. It claims about 2x fewer tokens than grep on 50 Claude Code Q&A tasks, judged by an LLM.

**Greptile**: the Claude Code plugin (https://claude.com/plugins/greptile) is mainly about PR review comments and searching Greptile-generated knowledge, with a Greptile API key. It is hosted and not a general semantic code index for local work.

## Comparison table

| Tool | Licence | Plugs in as | Embeddings, local? | Index location | Freshness | Langs (chunked) | Stars / last release / last push | Code leaves machine? |
|---|---|---|---|---|---|---|---|---|
| ck | MIT or Apache-2.0 | CLI (`--json`) + MCP (`ck --serve`) | FastEmbed BGE-Small (default), nomic, jina-code; local | `.ck/` in repo or `$CK_INDEX_DIR` | refresh before each search; blake3 chunk hashes | ~12 + plain text | 1,772 / 0.8.1 2026-10-11 / 2026-11-05 | No |
| ColGREP | Apache-2.0 | CLI (`--json`) + Claude Code hooks; no MCP | LateOn-Code-edge 17M on CPU; local | `~/.local/share/colgrep/indices/` | refresh before each search; file hashes | ~24 + docs | 624 / v1.8.5 2026-10-10 / 2026-10-10 | No |
| cocoindex-code | Apache-2.0 | plugin, skill, MCP, CLI | arctic-embed-xs local (`full`); or cloud via LiteLLM | `.cocoindex_code/` in repo | incremental; daemon; refresh on search | ~30 | 2,991 / v0.2.43 2026-11-05 / 2026-11-24 | No with `full` (telemetry on unless disabled); yes with cloud models |
| osgrep | Apache-2.0 | CLI + Claude Code hooks | ONNX local | `~/.osgrep/data` | watcher (`serve`) | ~15 | 1,152 / v0.5.16 2025-12-09 / 2026-01-17 | No |
| SeaGOAT | MIT | CLI + local server | ChromaDB default; local | local | background indexing | 12 | 1,320 / v1.6.1 2026-10-25 / 2026-11-23 | No (unless `--generative` with a cloud LLM) |
| claude-context-local | GPL-3.0 (README) | MCP | EmbeddingGemma 300M; local | local FAISS | Merkle DAG incremental | ~9 | 238 / v0.1 2025-09-06 / 2025-11-13 | No |
| grepai | MIT | MCP + CLI | Ollama (default), LM Studio, OpenAI | `.grepai/` (GOB), Postgres or Qdrant | watcher (`grepai watch`) | not listed | 1,954 / v1.2.0 2026-10-30 / 2026-11-02 | No with Ollama |
| ChunkHound | MIT | MCP (+ CLI) | Voyage (rec.), OpenAI, Ollama | local DuckDB | watcher in MCP mode | many via tree-sitter | 1,464 / v6.2.0 2026-11-23 / 2026-11-24 | No with Ollama |
| open-codebase-index | MIT | MCP, Claude Code plugin | Ollama, OpenAI, Google, custom | `.claude/` (SQLite + usearch) | watcher + git-aware incremental | ~25 | 235 / v0.40.1 2026-11-19 / 2026-11-24 | No with Ollama |
| Claude Context | MIT | MCP (npx) | OpenAI, Voyage, Gemini, Ollama | Milvus / Zilliz Cloud | Merkle-tree incremental, manual | 14 | 12,724 / npm only / 2026-11-24 | Yes as documented (OpenAI + Zilliz Cloud) |
| Augment Context Engine | proprietary | MCP (stdio local / HTTP remote) | Augment's, hosted | Augment | real time (local), on push (remote) | not stated | n/a | Yes (account; remote indexes on Augment) |
| Sourcegraph MCP | proprietary (Enterprise) | MCP over HTTP | Sourcegraph's | your instance | instance indexing | broad | n/a | To your instance (can be self-hosted) |
| mgrep | Apache-2.0 client | CLI + Claude Code plugin | Mixedbread, hosted | Mixedbread cloud store | watcher | code, text, PDFs, images | 4,443 / v0.1.13 2026-04-25 / 2026-04-25 | Yes, every file |

Index size and build time on a large repo are published only for ck (claimed about 1M LOC in under 2 minutes, index 1-3x source size) and ChunkHound (up to 180 million lines researched on a laptop, with no index size given). The other tools publish neither figure.

## Evidence: does semantic search help coding agents?

For:
- **Cursor** (vendor, own embedding model trained on agent traces): on Cursor Context Bench, semantic search plus grep gave "on average 12.5% higher accuracy in answering questions (6.5%-23.5% depending on the model)". In an online A/B test, code retention rose 0.3% overall and 2.6% on codebases of 1,000 or more files, and dissatisfied follow-ups were 2.2% higher without it. Cursor says "the combination of these two leads to the best outcomes" (https://cursor.com/blog/semsearch).
- **turbopuffer talk** (AI Engineer Europe 2026, 50 tasks, Claude Code, voyage-code-3): file precision went from 65% (stock) to 87% with windowed reads plus semantic search, but part of the gain came from windowed reads alone, and recall fell slightly. Semantic search helped find related behaviour under different keywords. It helped less once the agent had a good identifier, because grep does that better. Claude Code "is oriented toward grep" and lacks a policy for when to use semantic search (https://ai.engineer/talks/zKk7sDMGDEQ-benchmarking-semantic-code-retrieval-on-claude).
- **Small Agents with Semantic Search** (arXiv 2610.05099; most authors are from LightOn, the ColGREP maker): agents under 2B parameters with ColGREP beat grep agents on file F1, with 44.1% lower CPU latency and 29.1% fewer tokens. On SWE-bench Lite, though, the grep-based Qwen3-1.7B had higher class and function F1 after training (https://arxiv.org/abs/2610.05099).
- **Agent Retrieval Bench** (arXiv 2607.24882): dense Qwen3-Embedding models had the best MRR and Recall@20. A RepoMap-style structural map gave the best context yield at an 8K-token budget. "No single retrieval family dominates", and logged agent trajectories missed every gold file on 27-35% of samples (https://arxiv.org/abs/2607.24882).
- Vendor token claims: Claude Context -39.4% tokens at equal F1 (evaluation linked above), ColGREP 56% fewer search operations (LightOn blog), mgrep about 2x, osgrep about 20%, cocoindex-code 70% (READMEs). None is independently replicated.

Against, or "only sometimes":
- **Embeddings vs. Grep** (arXiv 2611.20455, Nov 2026, 91 repos, 6 languages): much of the dense advantage on standard benchmarks comes from unfair BM25 setups and from queries that lack the code's rare identifiers. Having an LLM generate identifiers and then grep for them ("generate-then-grep") lets BM25 match dense retrieval in every Python pool. In a SWE-agent test (96 tasks), grep, a lexical index, a dense index and a router all scored within about 0.04 exact-match: "the choice of LLM matters far more for localization than the search tool it calls." No method predicted per query which retriever would win. The authors' guidelines: use a fair lexical baseline, fuse dense with BM25, and add the code's own words to queries (https://arxiv.org/abs/2611.20455, https://arxiv.org/html/2611.20455).
- **Does a Language Server Save Tokens for Coding Agents?** (arXiv 2608.13568, Claude Opus 4.8, Sonnet 4.6, Haiku 4.5): models used semantic tools 0-6% of the time for localization. Semantic tools raised token use by 6-118% on symbol-named tasks, and saved tokens only for the weakest model. Grep handled multi-file renames perfectly, because renames also have to change comments and strings. The verdict is "conditional and usually negative", and the author recommends routing by task class, model and lexical noise (https://arxiv.org/abs/2608.13568).
- **Claude Code's own history**: an early version indexed the repo with embeddings. Agentic search "outperformed everything. By a lot", judged mostly on "vibes" plus some internal benchmarks. Reasons given: the index drifts out of sync, and a stored index is a security risk. Agentic search costs latency and tokens (Boris Cherny, https://www.latent.space/p/claude-code).
- **Cline** does not index: chunking "tears apart" code logic, an index is a frozen snapshot, and it is a second copy of the IP. It concedes "RAG can save tokens" (https://cline.bot/blog/why-cline-doesnt-index-your-codebase-and-why-thats-a-good-thing).
- **Sourcegraph** dropped embeddings from Cody in favour of its search engine in September 2024 (https://patch-diff.githubusercontent.com/raw/sourcegraph/docs/pull/672.patch).

What this means in practice:
- Semantic search helps on concept queries with no known identifier ("where is retry/backoff handled"), on large or noisy repos where grep floods results, on code that names the same idea differently in different places, for smaller or cheaper models, and for cutting tokens on exploratory questions.
- It does not help, or hurts, when the task names a symbol, file or error string; for renames and exhaustive reference finding (grep or the LSP is complete, embeddings are not); when the index is stale; and when the agent is not told when to use it. Left to itself, Claude defaults to grep.
- The safest design is hybrid (BM25 or grep fused with vectors), used as a first step for finding where to look, followed by grep, structural navigation and reading files to confirm.

## Privacy

- **Nothing leaves the machine:** ck, ColGREP, osgrep, SeaGOAT and claude-context-local, after a one-time model download from Hugging Face or GitHub. cocoindex-code `full` keeps code local but sends usage telemetry unless `COCOINDEX_DISABLE_USAGE_TRACKING=1` is set. grepai, ChunkHound and open-codebase-index stay local only with Ollama.
- **Sends code out:** Claude Context as documented (OpenAI embeddings plus Zilliz Cloud), any tool pointed at OpenAI, Voyage, Gemini, Cohere or similar, mgrep (every file goes to the Mixedbread cloud), Augment (account; remote mode indexes on Augment), and Sourcegraph (to your instance, which may be self-hosted).
- An embedding index is a derived copy of the code. Keep it out of git and out of shared folders (the Cline and Cherny objections above).

## Recommendation: local-first default

Offer **ck** as the default semantic option inside the "Code map for a large codebase" proposal. Name **ColGREP** as the alternative, and **cocoindex-code** for teams that want a Claude Code plugin with about 30 languages.

Why ck:
1. **Local and private by default.** It needs no account, no server, no Ollama and no Python, and works offline after the model download (README FAQ).
2. **Hybrid search.** `--hybrid` fuses BM25 with vectors, which is the main recommendation of the independent "Embeddings vs. Grep" paper.
3. **Callable both ways.** Subagents can run it from Bash (`ck --jsonl --hybrid --topk 10 "<query>" .`) without the MCP server being loaded, and `ck --serve` serves sessions that do use MCP.
4. **Freshness built in.** Every semantic or hybrid search re-embeds only changed chunks first. `ck --status .` and the MCP `index_status` give idleflow a health check.
5. **Licence and maturity.** MIT or Apache-2.0, about 1.8k stars, a release in October 2026, and a push in November 2026.

Cons to state in the proposal:
- The speed and size figures are README claims only.
- The index goes in `.ck/` inside the repo unless `CK_INDEX_DIR` is set, so it must be ignored.
- Its tree-sitter chunkers do not cover Java, PHP or Swift yet. Repos in those languages get plain-text chunks, so propose ColGREP (which covers them) for them.
- No published agent benchmark exists for ck.

Why not the others as the default:
- ColGREP is equally local, has a vendor Claude Code benchmark, and keeps its index outside the repo. It has no MCP server, though, and its Claude Code integration installs hooks.
- cocoindex-code pulls in about 1 GB of torch, sends telemetry by default, and has an LMDB size ceiling on large repos.
- grepai, ChunkHound and open-codebase-index need Ollama running.
- Claude Context needs Milvus and, as documented, cloud services.

## What idleflow needs

1. **Record the accepted map.**
   - Keep today's `Stack decisions` line format in `.idleflow/conventions.md` (procedures/repo-setup.md R3 step 5).
   - Add a machine-readable "Code map" block that agents read before searching:
     ```
     ## Code map
     - kind: semantic | structural | both
     - tool: ck 0.8.1   (install: <verified command>; research: docs/research/code-index.md)
     - query: ck --jsonl --hybrid --topk 10 "<query>" .
     - status: ck --status .
     - index_dir: $CK_INDEX_DIR or .ck/ (ignored)   model: bge-small
     - built_at_commit: <sha>   built_at: <date>
     - use_for: concept queries with no known identifier; first step when grep returns too many hits
     - not_for: renames, exhaustive references, named symbols/strings (use grep / the structural map)
     ```
   - Put the index path in the ignore rules, whatever `ignore_in:` says, because an index is a derived copy of the code.
   - Accepting the map becomes a plan task (index once, add the ignore entry, add the block), the same way other accepted stack decisions become tasks today.
2. **How agents query it.**
   - Add one instruction to the explorer, planner, implementers and reviewers: read the Code map block. For a concept question, run the `query:` command first. Treat its hits as candidates and confirm with grep or a file read before citing them. Never use it for renames or for "find every caller".
   - Prefer the CLI over MCP for subagents, because a CLI needs no Claude Code restart and works in worktrees.
   - In a worktree, either point `CK_INDEX_DIR` at the main checkout's index, which costs one incremental refresh on the first query, or let the worktree build its own index. Measure which is cheaper before choosing.
   - Have the explorer log in `context.md` whether it used the map, so the retro can learn whether the map helps. The papers show agents ignore it unless told to.
3. **Detect a stale index.**
   - ck and ColGREP refresh on every search, so staleness there means a missing index, a model change, or a tool version change.
   - At run start, `doctor` or the explorer runs the `status:` command. If it fails or reports no index, the map is unavailable.
   - For tools without refresh-on-search (Claude Context, claude-context-local), compare `built_at_commit` with `git rev-parse HEAD`. Use `git diff --name-only <built_at_commit>..HEAD | wc -l` against a threshold to decide whether to re-index before the run, and update `built_at_commit` after a successful re-index.
   - Record the tool version and model. A different installed version or model means a full rebuild (ck `--switch-model`; cocoindex-code also requires a re-index after a model change).
4. **Fallback when it is unavailable.** If the binary is missing, `status` fails, or the index is mid-build, say so once in `context.md` (`code map unavailable: <reason>`) and continue with grep and the structural map. Never block a run on the index. Write a `plugin_gap` line only if the cause is idleflow's own (for example, a missing config knob). When the semantic tool is the only map and it is down, the structural fallback is the repo map file or ctags, if one exists.
5. **Research inputs.** Add the semantic candidates (ck, ColGREP, cocoindex-code, grepai+Ollama, ChunkHound+Ollama, Claude Context, Augment, Sourcegraph `nls_search`, mgrep) to the stack researcher's candidate list in `agents/stack-researcher.md`, next to Graphify, Serena, Sourcegraph, ctags and the repo map. Have it mark for each one whether code leaves the machine.
