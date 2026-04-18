# ADR-002: Memory backend — Engram MCP replaces markdown files

**Status**: Accepted (2026-04-18)

## Context

v4 stored memory as flat markdown in `~/.omnicoder/memory/`:
`patterns.md`, `feedback.md`, `project_*.md`, `user_*.md`, `reference_*.md`.
Loaded into every session by `memory-loader.sh` with a 1200-byte cap.
Problems: no cross-CLI sharing (Claude Code, Codex, Cursor each had their own), no search, no versioning, no concurrent-write safety, cap forces arbitrary truncation.

## Decision

Adopt **Engram** (gentle-ai, v1.12.0) as the default memory backend, exposed through its MCP stdio server.

- Binary: single ~5 MB static Go, pure-Go SQLite (`modernc.org/sqlite`, no CGO), 6 platform targets.
- Data path: `$ENGRAM_DATA_DIR` (defaults to `~/.engram/`).
- MCP tools exposed (15): `mem_save`, `mem_update`, `mem_delete`, `mem_search`, `mem_context`, `mem_timeline`, `mem_get_observation`, `mem_session_start`, `mem_session_end`, `mem_session_summary`, `mem_save_prompt`, `mem_stats`, `mem_capture_passive`, `mem_merge_projects`, `mem_suggest_topic_key`.
- Concurrency: SQLite WAL + `busy_timeout=5000ms` → safe for parallel Opencode, Claude Code, Codex sessions.

## Migration path

One-shot script `scripts/migrate-memory-v4-to-engram.ts`:
```
for file in ~/.omnicoder/memory/*.md:
  type   = prefix(file)  # patterns|feedback|project|user|reference
  title  = frontmatter.name || h1
  body   = markdown content
  POST /observations { type, title, content: body, project: "omnicoder" }
```

Dual-read window: v5.0 → v5.1 the `memory-loader` plugin reads **both** Engram and `~/.omnicoder/memory/*.md`, merges and deduplicates. v5.2 drops markdown fallback.

## Consequences

**Positive**
- Shared across every MCP-capable agent on the machine. One source of truth.
- FTS5 lexical search replaces the v4 1200-byte cap with relevance-ranked retrieval.
- Atomic writes, versioning (`revision_count`), timeline, passive capture.

**Negative / known gaps**
- FTS5 is lexical, not semantic embeddings. For paraphrase-heavy queries we add an HNSW layer in v5.2 (separate ADR).
- No native import tool → the one-shot script is ours to maintain.
- No metadata JSON blob — extras go in `content` as structured YAML/front-matter inside the observation.

## Rejected alternatives

- **mcp-memory-service (doobidoo)**: Python, REST + knowledge graph. Heavier deps, Python runtime mandatory.
- **Mastra semantic recall**: framework-ish, larger footprint, less agent-agnostic.
- **Stay on markdown**: v4 limitations documented above; punting the problem.
- **Custom SQLite + FTS5 in TypeScript**: reinventing Engram for no gain.
