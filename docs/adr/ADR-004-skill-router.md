# ADR-004: Skill router — lexical first, embeddings in v5.2

**Status**: Accepted (2026-04-18)

## Context

v4 routed 193 skills + 168 agents with BM25 + bigrams over `name + description`, cached in `.router-cache/`. Warm latency 19 ms. Good enough for exact-keyword matches; misses paraphrases ("review my PR" finds `pr-review` but not `code-review`).

Opencode's native `src/skill/discovery.ts` does simpler substring matching. Insufficient for 361 assets.

## Decision

**v5.0**: Port the v4 BM25-bigram router as-is into `@omnicoder/core/router`. Single-stage lexical.
**v5.2**: Add a second stage: offline-embed all skill `name + description` with a small model (`gte-small`, 33 MB, 384-dim), store vectors in Engram (`mem_capture_passive` with `type=skill-index`), retrieve top-20 via HNSW at query time, rerank with BM25.

## Why two stages, why now only the first

- Shipping v5.0 with embeddings delays the release by ≥ 2 weeks for embedding infra + model download UX.
- BM25-bigram already catches ~85% of queries (v4 data). The remaining 15% paraphrases are the explicit target of v5.2.
- SkillRouter paper (arxiv 2603.22455) validates that the 2-stage approach is the right direction, not a speculative optimisation.

## Consequences

**Positive**
- Ship v5.0 without new ML deps.
- v5.2 upgrade is additive — the BM25 layer stays as fallback if embeddings fail to load.

**Negative**
- Users with heavy paraphrase workloads will notice gaps until v5.2.
- Embeddings infra is a new moving part to maintain (model pinning, cache invalidation on skill changes).

## Rejected alternatives

- **Ship with embeddings in v5.0**: timeline risk, unclear memory footprint on low-end machines.
- **Drop BM25, pure vector search**: lexical still wins on exact skill-name queries and costs ~1 ms per query.
- **Use Opencode's native discovery**: not scalable to 361 assets; no ranking.
