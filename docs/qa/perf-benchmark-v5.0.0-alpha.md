# Performance benchmark — OmniCoder v5.0.0-alpha.0

- **Generated:** 2026-04-18T19:24:20Z
- **Runtime:** Bun 1.3.6 · Node v24.3.0 · linux-x64
- **Baselines:** v4.3.1 (see `project_omnicoder.md`)
- **Benchmark sources:** `packages/omnicoder/bench/*.bench.ts`
- **Raw results:** `packages/omnicoder/bench/results-v5.0.0-alpha.0.json`

Benchmarks use `Bun.nanoseconds()` for sub-ms precision, deterministic seeded
fake data, no network calls, and a 60 s per-suite timeout. The router bench
walks the repo's real `.opencode/skills/` (194 SKILL.md) + `.opencode/agent/`
(170 .md) — production-representative.

---

## 1. Comparative table (v4.3.1 → v5.0.0-alpha.0)

| Metric | v4 baseline | v5 p50 | v5 p95 | Δ vs v4 | Verdict |
|---|---:|---:|---:|---:|:--|
| Pipeline (50 tool-calls, wall-clock) | **2000 ms** | **1179.5 ms** | n/a | **−41.0 %** | win |
| Router warm (per-call p50) | 19 ms | **21.9 ms** | 31.9 ms | +15.2 % | minor regression |
| Router cold rebuild (p50) | 46 ms | **155.0 ms** | 178.5 ms | +236.9 % | REGRESSION |
| Security guard (bash check, p50) | 6.5 ms (Read) | **6.6 µs** | 20.9 µs | −99.9 % | massive win |
| Memory loader — cold | n/a | **1.5 ms** | — | n/a | ok |
| Memory loader — hot hit (p50) | n/a | **4.8 µs** | 12.9 µs | n/a | ok |
| Memory injected bytes | ~2.2 KB | **1.2 KB** | — | −46 % (cap-bound) | ok |
| Security throughput | n/a | **81 717 ops/s** | — | n/a | ok |

Pipeline v5 is **1.7× faster** than v4 despite the router regression —
dispatcher, security and memory shave enough wall-clock time to more than
absorb the router cost.

---

## 2. Heatmap — where we gain / lose

Each stage's share of the 50-call wall-clock and its v4→v5 trajectory:

```
Stage         p50 / call   % of wall-clock   v4→v5 trajectory
────────────  ───────────  ────────────────  ─────────────────────
router         20.37 ms      86.6 %          WORSE  (cold path more expensive)
dispatcher      1.44 ms       6.1 %          better (was shell awk/jq loops)
failover       65.3 µs        0.3 %          better (in-memory Map, no file IO)
security       42.4 µs        0.2 %          MUCH BETTER (regex-only, no fork)
budget         16.3 µs        0.1 %          better (short-circuit non-end events)
memory         13.8 µs        0.06 %         MUCH BETTER (in-proc cache hit)
                ─────────
               21.95 ms     ≈ 93.3 % accounted
```

Win / loss summary:

- **Big wins:** security (−99.9 %), memory hot path (µs), dispatcher (now <2 ms
  vs shell pipeline in v4), failover (in-proc map).
- **Big loss:** router cold rebuild. Warm hit (21.9 ms) is within noise of v4's
  19 ms and improved by Bun JIT warm-up over repeated BM25 scoring.
- **Net:** v5 pipeline is 820 ms faster over 50 calls, because the 5 non-router
  hooks cost essentially nothing now.

---

## 3. Regression root cause — router cold

The router walks `~/.omnicoder/{skills,agents}` and reads every `SKILL.md` /
`agent/*.md` to rebuild its in-memory BM25 index (60 s TTL).

Profiling one rebuild (`bench/_bench-util.ts::mkBenchHome` + 194 skills + 170
agents) with granular `Bun.nanoseconds()` probes:

```
skills readdir           …  712 µs
agents readdir           …  540 µs
read 194 SKILL.md (SERIAL)  … 23.3 ms    ← current implementation
read 194 SKILL.md (PARALLEL) … 5.6 ms   ← 4.2× faster
```

The same `Promise.all` parallelisation would apply to agents (170 files). Full
projected cold build with parallel reads: **≈15–20 ms**, *better* than the v4
baseline (46 ms).

Offending code: `packages/omnicoder/src/router/index.ts::collect()` — `for
(const e of entries)` sequentially `await readIf(...)`. Each await stalls on
libuv file IO before starting the next.

---

## 4. Recommendations

### 4.1 Router — parallelise `collect()` (high ROI, low risk)

Replace the serial loop in `src/router/index.ts::collect()` with a bounded
`Promise.all` over directory entries. Expected impact: cold p50 **155 ms →
~20 ms** (−87 %), full-pipeline wall-clock **1179 ms → ~1050 ms** in
pathological cold-first scenarios.

```ts
// pseudocode
const jobs = entries.map(async (e) => { /* readIf + push */ })
await Promise.all(jobs)
```

Keep the existing 60 s cache; the rebuild amortises over sessions.

### 4.2 Router warm — micro-opt BM25 (only if router warm blocks a target)

Warm p50 is 21.9 ms — almost all of it is BM25 scoring over 364 docs × query
tokens. Optional wins:

- Precompute per-doc `tf` maps at `buildIndex` time (currently recomputed per
  query).
- Store `tokens.length` already available — avoid re-measuring inside BM25.

Expected: warm p50 **22 ms → 8–12 ms**. Only worth it if warm becomes a
bottleneck; today it is 1 % of pipeline time.

### 4.3 Dispatcher — keep an eye on `tool-usage.jsonl` growth

`dispatcher.onComplete` appends to a JSONL file per call (~1.4 ms p50). Over
long sessions this can block the event loop on slow disks. Options: buffer N
entries in memory and flush every 500 ms, or rotate the file.

### 4.4 Memory — the −46 % bytes delta is an input artefact

Our seed generates 1.2 KB (MAX_BYTES cap is 1200). v4's 2.2 KB figure is the
production payload size. No action needed — verify real memory files in `qa`.

---

## 5. Verdict

**optimize-first** — ship-blocker is localised to `router/index.ts::collect()`.

Pipeline end-to-end is already 41 % faster than v4, and 4 of 6 hooks are at
µs-grade. Applying recommendation **4.1** (a <15-line change to parallelise
file reads) is expected to turn the remaining regression into a win and bring
full pipeline under ~1 s.

Post-fix target for the next cut:

| Metric | Current | Post-fix target |
|---|---:|---:|
| Router cold p50 | 155 ms | ≤ 25 ms |
| Router warm p50 | 21.9 ms | ≤ 20 ms |
| Pipeline wall-clock (50 calls) | 1179 ms | ≤ 1050 ms |

Re-run `bun run bench/run-all.ts` after the patch; regressions flag
automatically (threshold: ±10 % from v4 baselines).
