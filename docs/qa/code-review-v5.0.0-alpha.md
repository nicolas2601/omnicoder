# Code Review — OmniCoder v5.0.0-alpha

**Reviewer**: code-review subagent (parallel reviewer + static-analyst + architect)
**Date**: 2026-04-18
**Branch**: `v5-migration` at `fd1a94b`
**Complements**: `security-audit-v5.0.0-alpha.md` (does not duplicate findings)

## Verdict

**GO for alpha release. NO-GO for v5.0.0-stable without 4 MUST fixes.**

Quality is notably high for an alpha: 0 unjustified `any`, 763 LOC total within ADR-003 budget, coherent error handling, tests with realistic fixtures. Three architectural findings affect correctness (not security): (1) module-level state in provider-failover breaks isolation, (2) JSONL logs grow monotonically without rotation, (3) router cache has a race on concurrent startup.

## Findings

| ID | Dim | Sev | Location | Summary |
|----|-----|-----|----------|---------|
| CR-01 | Arch | **MUST** | `hooks/provider-failover.ts:18` | `blocked` Map at module scope; two workspaces share state. Move to closure. |
| CR-02 | Arch | **MUST** | `budget/index.ts:86-89`, `hooks/tool-dispatcher.ts:35-42` | JSONL appends without rotation. Add size-based rotation helper. |
| CR-03 | Arch | **MUST** | `router/index.ts:103-107`, `memory/index.ts:86-91` | Race on cache miss: two concurrent calls do duplicate work. Use in-flight promise. |
| CR-04 | Arch | **MUST** | `.omnicoder/opencode.jsonc` vs ADR-005 | ADR promises agent role → provider map; jsonc lacks `agent` block. Either add the block or rephrase the ADR. |
| CR-05 | Quality | SHOULD | 4 files | `resolveHome()` duplicated. Extract `util/paths.ts`. |
| CR-06 | Static | SHOULD | `router/index.ts:44-62` | `collect()` flat-only; document policy or recurse with depth limit. |
| CR-07 | Static | SHOULD | `budget/index.ts:65-78` | `readTail(n)` reads whole file. Tail from `size - 64KB` instead. |
| CR-08 | Quality | SHOULD | `security/index.ts:96-103` | Whitelist fall-through path has no test covering "nothing matches". |
| CR-09 | Static | SHOULD | `security/index.ts:9-29` | DANGEROUS re-runs 19 regex per call. Consider union regex with /i global. |
| CR-10 | Tests | SHOULD | 3 test files | `expect(true).toBe(true)` anti-pattern. Assert real side-effects. |
| CR-11 | Arch | SHOULD | `index.ts:30-48` | Adding a 7th hook touches 3 places. Refactor to module registry. |
| CR-12 | Tests | SHOULD | all unit tests | Unit tests share module singletons. Use cache-busting or closure state. |
| CR-13 | Quality | SHOULD | 4 files | Duplicated pattern "prefer $HOME" without consistent doc-comment. |
| CR-14 | Static | NICE | `security/index.ts:50-58` | `instanceof SecurityError` fragile across module reloads. |
| CR-15 | Static | NICE | 3 files | Hardcoded TTL/MAX constants; make configurable via plugin options in v5.1. |
| CR-16 | Arch | NICE | `index.ts:44-47` | `event` parameter not strictly typed. |
| CR-17 | Quality | NICE | `omnicoder-pr.yml:53-56` | `echo TODO` placeholder for coverage gate. Implement or `if: false`. |
| CR-18 | Tests | NICE | `performance-smoke.test.ts:66-86` | Absolute thresholds, no delta-vs-baseline check. |
| CR-19 | Static | NICE | `router/index.ts:63-77` | `collect()` is sequential I/O; parallelise with `Promise.all`. |
| CR-20 | Arch | NICE | multiple | `input` param unused in factories; leave TODO once future need appears. |

## Estimated branch coverage

| Module | LOC | Branch coverage |
|--------|-----|-----------------|
| router | 142 | ~78% |
| security | 107 | ~90% |
| memory | 114 | ~82% |
| budget | 120 | ~65% |
| tool-dispatcher | 93 | ~70% |
| provider-failover | 78 | ~75% |
| index | 51 | ~85% |

**Global estimate: ~78%**. Good for alpha. Gaps: cache TTL expiration, filesystem error paths, budget number parsing.

## Quality score: 8.2 / 10

| Dimension | Score |
|---|---|
| Readability & naming | 9 |
| Cyclomatic complexity | 9 |
| Error handling | 8 |
| Testability | 7 |
| DRY | 6 |
| ADR compliance | 9 |
| Type safety | 10 |
| Concurrency safety | 6 |

## Must-fix before v5.0.0-stable

1. CR-01 — closure for `blocked` state
2. CR-02 — JSONL rotation helper
3. CR-03 — in-flight de-dup for cache builds
4. CR-04 — ADR-005 ↔ config alignment

## Can wait (v5.1+)

CR-05 through CR-20 ordered by impact above.
