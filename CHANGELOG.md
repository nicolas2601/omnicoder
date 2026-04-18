# Changelog

All notable changes to OmniCoder v5 will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.0.0-alpha.1] — 2026-04-18

Second alpha, closing the SEC-05 / bun-install / MIGRATION gaps left open by alpha.0 and adding a professional README + 7 topical docs modelled after the v4 documentation layout.

### Added

- `docs/MIGRATION.md` — complete v4 (Qwen Code) → v5 migration guide with hook matrix, paths matrix, rollback procedure, and known issues.
- Topical documentation in `docs/`:
  - `01-quickstart.md` — 5-minute onboarding for Linux / macOS / Windows.
  - `02-install.md` — detailed installer flags, one-liner, user-local install, update flow.
  - `03-providers.md` — provider matrix (NVIDIA NIM, MiniMax, DashScope, Anthropic, OpenAI), failover logic, custom-provider guide.
  - `04-skills-agents.md` — skill/agent formats, 360+ ported assets, enable/disable, debugging the router.
  - `05-hooks.md` — per-hook deep dive, execution order diagram, how to write & register a new hook + test.
  - `06-benchmarks.md` — test suite layout, CI matrix, baseline ops/sec, v4 → v5 comparison.
  - `07-troubleshooting.md` — installer / runtime / hooks / CI / sync tables.
  - `control-del-cli.md` — repo anatomy, how to add a subcommand, patch upstream safely, rebrand.
  - `uninstall.md` — Linux/mac/Windows uninstall + purge procedures with backup guidance.
- Root `README.md` rewritten in v4 style: one-screen quickstart, links to the 8 docs, state table, architecture map.

### Changed

- SEC-05 HIGH closed: installer (Linux + Windows) verifies the Engram download against `ENGRAM_SHA256_<PLATFORM>` pins. When the env var is empty the installer warns and proceeds, matching the documented dev flow.
- SEC-07 closed: `omnicoder-ci.yml` runs `bun install --frozen-lockfile` on all three OSes before typecheck / test.
- `README.md` reorganised to surface documentation tree and current metrics, mirroring the compact `omnicoder v4` layout.

### Fixed

- Removed hackathon-specific quickstart draft; onboarding consolidated into `docs/01-quickstart.md`.

### Known issues

- Mid-session provider failover still blocked on upstream #7602; alpha.1 keeps log-only behaviour.
- Engram default checksum pins are empty — users who need signed installs must export `ENGRAM_SHA256_*` until we ship a release matrix (tracked for alpha.2).

## [5.0.0-alpha.0] — 2026-04-18

Initial alpha of OmniCoder v5. Base change: forked from [sst/opencode](https://github.com/sst/opencode) v1.4.11. See `docs/adr/ADR-001-fork-opencode.md` for rationale.

### Added

- `@omnicoder/core` plugin package at `packages/omnicoder/` with six hooks:
  - `router/` — BM25 + bigram skill routing over 361 assets (193 skills + 168 agents).
  - `security/` — bash command guard with 19 dangerous / 3 secret patterns, separator-aware to prevent whitelist bypass (SEC-01).
  - `memory/` — loads `patterns.md` + `feedback.md`, caps at 1200 bytes, skipped when Engram MCP is configured.
  - `budget/` — JSONL token log with rolling-average alerting at 15 k/session.
  - `hooks/tool-dispatcher.ts` — JSONL tool-usage log, never throws.
  - `hooks/provider-failover.ts` — 60 s cool-down window (full mid-session failover deferred to v5.1, upstream gap).
- `.omnicoder/opencode.jsonc` default config: NVIDIA NIM + MiniMax + DashScope providers, Engram MCP, expanded permission denylist.
- `.opencode/agent/` — 167 agents ported from v4 (`agents-orchestrator` promoted to `primary`).
- `.opencode/skills/` — 193 skills ported from v4 with `SKILL.md` format.
- Five ADRs (fork, memory backend, hooks TS, skill router, provider chain) under `docs/adr/`.
- CI workflows: `omnicoder-ci.yml` (3-OS matrix), `omnicoder-release.yml`, `omnicoder-pr.yml` with CHANGELOG gate, `dependabot.yml`, `CODEOWNERS`.
- Test suite: 45 tests (21 unit + 24 integration) across 12 files, ≤200 ms total.

### Changed

- 19 upstream workflows gated with `if: github.repository == 'sst/opencode'` to avoid running on the fork.
- LICENSE now attributes both SST (original) and nicolas2601 (derivative). NOTICE file added.

### Security

- **SEC-01 CRITICAL fix**: security guard whitelist bypass via `&&`, `;`, `|`, `$()`, `` ` `` closed. Regression suite added.
- **SEC-03 HIGH fix**: permission denylist extended to `.ssh/`, `.aws/`, `.gcp/`, `.azure/`, `.kube/config`, `.docker/config.json`, `.npmrc`, `.netrc`, `.config/gh/`.
- **SEC-04 fix**: `sudo *` changed from `ask` to `deny` in config for consistency with runtime guard.
- **SEC-06 HIGH fix**: MIT attribution to SST restored in LICENSE; NOTICE added.

### Known issues

- `bun install` has not yet been run in CI; supply-chain audit (SEC-07) pending.
- Engram checksum pinning (SEC-05 HIGH) deferred to v5.0.0-alpha.1 installer.
- Mid-session provider failover unsupported in Opencode mainline (upstream #7602); v5.0 ships log-only.

### Migration from v4

See `docs/MIGRATION.md` (to be added in alpha.1). Markdown memory files under `~/.omnicoder/memory/` will be read during a v5.0→v5.1 transition; v5.2 will deprecate them in favour of Engram.
