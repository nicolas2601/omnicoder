# Changelog

All notable changes to OmniCoder v5 will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.0.0-alpha.8] — 2026-04-19

First real patch to opencode core since the fork. `/personality` becomes a
native TUI slash command with a visual picker instead of the old markdown
command that just printed help text at the orchestrator.

Cross-platform install + auto-update flow is finalised: npm on Linux,
macOS, and Windows (same single command, XDG-correct seed paths).

### Added

- **Native `/personality` dialog** — new
  `packages/opencode/src/cli/cmd/tui/component/dialog-personality.tsx`
  (marked `// OMNICODER:`). Slash registered in `app.tsx` under the
  "OmniCoder" category. Writes selection to
  `~/.omnicoder/personality.json`.
- **Personality loader** — new `packages/omnicoder/src/personality/`
  module. `@omnicoder/core` injects a preamble into the system prompt
  before the memory + router hooks. 6 personas shipped (Omni-Man,
  Conquest, Thragg, Anissa, Cecil, Immortal) + Off. 30s cache, 6 unit
  tests.
- **Subcomandos del wrapper**:
  - `omnicoder update` / `upgrade` — re-ejecuta `npm install -g
    @nicolas2601/omnicoder@alpha` y fuerza re-seed de agents/commands.
  - `omnicoder --version` / `-v` — ya no pasa flag a opencode; imprime
    versión, runtime subyacente (opencode-ai), node, platform, binary.
  - `omnicoder seed [--force]` — re-siembra assets sin lanzar la TUI.
- **Background update check** — al arrancar, chequeo no-bloqueante contra
  registry.npmjs.org (cacheado 24h, skip si no es TTY, disable con
  `OMNICODER_NO_UPDATE_CHECK=1`). Si hay versión mayor, imprime hint
  violeta con el comando para actualizar.
- **Guía de Windows** en `docs/install-paula.md` (pasos de limpieza de
  instalación vieja, npm install, env vars via PowerShell, troubleshoot).

### Fixed

- **Windows path compatibility** — `scripts/seed-config.cjs` ahora
  resuelve el directorio de config vía XDG-correcto:
  - Linux: `~/.config/opencode/`
  - macOS: `~/.config/opencode/`
  - **Windows: `%APPDATA%\opencode\`** (antes apuntaba a
    `~/.config/opencode/`, donde opencode no los buscaba).
  El `routing-cli.mjs` generado por `bundle-assets.mjs` usa la misma
  lógica.
- **Upgrade seed flag** — el flag `~/.omnicoder/.seeded-alpha7` se
  elimina para que la subida a alpha.8 vuelva a sembrar los assets.

### Removed

- `.opencode/command/personality.md` — el markdown command viejo que
  solo imprimía el help del shell script. Reemplazado por el dialog
  nativo. Si querés el comportamiento shell, los scripts viejos siguen
  en `scripts/personality-assets/`.

## [5.0.0-alpha.7] — 2026-04-19

First release published to npm. OmniCoder is now installable cross-platform
with a single command — no more cloning the repo or running bootstrap
scripts.

### Added

- **npm package `@nicolas2601/omnicoder`** — thin Node.js wrapper around
  `opencode-ai` that ships 172 agents, 29 commands, the "omnicoder" purple
  theme, and 7 per-phase routing presets bundled as static assets.
  Cross-platform (Linux / macOS / Windows) because it piggybacks on
  opencode-ai's existing per-platform binaries.
- **`bin/omnicoder.mjs`** — Node launcher that resolves opencode's
  per-platform binary via `require.resolve("opencode-ai/package.json")`,
  seeds user config on every launch (idempotent, skips if already seeded),
  and transparently spawns opencode with our env vars (`OMNICODER=1`,
  `OMNICODER_VERSION`).
- **`bin/omnicoder-routing.mjs`** — standalone JSONC editor for per-phase
  routing presets (same capability as the dev-mode `omnicoder-routing`
  shell script, now portable across OSes).
- **`scripts/seed-config.cjs`** — idempotent copy of agents / commands /
  theme / presets into `~/.config/opencode/` and `~/.omnicoder/`. Never
  overwrites user edits; flag file `~/.omnicoder/.seeded-alpha7` short-
  circuits on repeat launches.
- **`scripts/bundle-assets.mjs`** — build step run by `npm pack`
  `prepack`. Snapshots `.opencode/{agent,command}/`, the theme, and
  routing presets into `packages/omnicoder-npm/assets/` so the tarball is
  fully self-contained (no network fetch at install time).
- Workflow `omnicoder-release.yml`: new `Pack @nicolas2601/omnicoder`
  step syncs the npm package version with the git tag, runs `npm pack`,
  and `npm publish --access public --tag <dist-tag>` (dist-tag resolves
  from the version suffix: `-alpha.*` → `alpha`, `-beta.*` → `beta`,
  `-rc.*` → `next`, stable → `latest`). Publish is skipped with a warning
  if `NPM_TOKEN` is unset, so forks without a token don't hard-fail.

### Changed

- `packages/omnicoder/src/security/index.ts`: `createSecurityGuard`'s
  `PluginInput` argument is now optional. The value is only used for
  future hooks; making it optional lets tests (and non-plugin callers)
  instantiate the guard without fabricating a full `PluginInput`.

### Installation

```bash
npm install -g @nicolas2601/omnicoder@alpha
omnicoder                     # launch TUI
omnicoder-routing list        # list presets
omnicoder-routing apply balanced
```

Package size: 733 kB tarball / 2.2 MB unpacked / 213 files. Depends on
`opencode-ai ^1.14.18` (npm resolves the correct binary per platform at
install time).

## [5.0.0-alpha.6] — 2026-04-18

Fix the silent "orchestrator never delegates" bug. Two structural gaps
caused the symptom users reported ("agents-orchestrator doesn't search
skills, doesn't call other agents"):

1. Opencode's agent discovery walks `~/.config/opencode/{agent,command}/`
   (and `.opencode/` dirs on the current path), but the fork's 170
   specialists were only seeded into `~/.omnicoder/{agents,skills}/`.
   None of them were visible to the TUI unless you launched it from the
   repo root, so every `task(subagent_type: ...)` call fell through with
   `Unknown agent type`.
2. The orchestrator's own markdown told the model to "Please spawn a
   project-manager-senior agent" in plain English — no tool call. The
   model obediently printed that sentence and moved on, never invoking
   the `task` tool.

### Fixed

- `scripts/install.sh` + `scripts/install-windows.ps1`: mirror the fork's
  `.opencode/agent/` and `.opencode/command/` into the user-global
  `~/.config/opencode/agent/` and `~/.config/opencode/command/`
  (Linux/macOS) / `%APPDATA%\opencode\agent,command` (Windows). Copy is
  idempotent / copy-if-missing so local edits survive re-install.
- `.opencode/agent/agents-orchestrator.md`: declares `tools.task: true`
  explicitly (with bash/read/write/edit/glob/grep/todowrite/webfetch) and
  adds a "CRITICAL: how to actually delegate" block that shows the exact
  `task(description, prompt, subagent_type)` signature plus the canonical
  subagent_type names the model should prefer. Color bumped to the new
  OmniCoder purple accent `#b077ff` to match the rebrand.

### Impact

After an install that includes these changes the orchestrator can really
spawn `project-manager-senior`, `engineering-senior-developer`,
`testing-reality-checker`, and the rest — plus the `general-purpose` /
`explore` Claude-Code-style aliases added in alpha.4 — without the user
having to cd to the repo or type agent paths by hand.

## [5.0.0-alpha.5] — 2026-04-18

Rebrand follow-up. Alpha.4 tried to hand-draw an "omnicoder" block banner
and ended up rendering as `OANIO OODER` on a live terminal — the colour
markers `_^~` only work for the TTY path, and plain Unicode substitutes
for `m`/`n`/`i`/`r`/`c` gave up legibility. Backed that out and rebuilt
the rebrand around surfaces that render reliably.

### Fixed

- `packages/opencode/src/cli/logo.ts` and `packages/opencode/src/cli/ui.ts`:
  reverted to the upstream `opencode` block glyphs so the splash is
  readable. Product branding now lives in the terminal title, the CLI
  help text, the theme palette, and the user config.
- Installer scripts (POSIX + Windows) now run `bun install` against the
  repo when bun is available and `packages/opencode/node_modules` is
  missing. Without that step the `omnicoder` wrapper's source-preferred
  path short-circuits to the global npm binary, which is exactly what
  produced "opencode green" instead of the purple theme after alpha.4.
- `bin/omnicoder.ps1`: same source-preference logic as `bin/omnicoder`.
  On Windows, when the repo is checked out with deps staged,
  `omnicoder` now launches `bun run --cwd ...\packages\opencode
  --conditions=browser src/index.ts`.

### Changed

- `.omnicoder/opencode.jsonc` template: ships `"theme": "omnicoder"`
  explicitly, so `install.sh` / `install-windows.ps1` seed the purple
  palette without relying on the fallback default in the code path
  (which is overridden by any earlier KV value).
- Terminal title set by the TUI: `OpenCode` → `OmniCoder`;
  `OC | <session>` → `OMNI | <session>`.

### Rationale

The product name shows up on screen through three reliable surfaces:
the terminal title bar (always set), the `--help` text (controlled by
`thread.ts` describe), and the colour palette (a full theme swap).
Block-art is the worst surface for rebranding a fork because every
glyph needs matching shadow markers or it looks broken, which is what
happened in alpha.4.

## [5.0.0-alpha.4] — 2026-04-18

Rebrand pass. The TUI now opens on "omnicoder" instead of "opencode" and
defaults to a purple palette, and two Claude Code-style agent aliases
(`general-purpose`, `Explore`) close the "Unknown agent type" error that
showed up when MiniMax/NIM tried to spawn subagents.

### Added

- `.opencode/agent/general-purpose.md` — alias for open-ended multi-step
  research / code search, matching the Claude Code taxonomy so models
  trained on those prompts spawn without failing.
- `.opencode/agent/explore.md` — read-only codebase exploration alias
  (Glob / Grep / Read / read-only Bash only). Forbidden from Edit / Write.
- `packages/opencode/src/cli/cmd/tui/context/theme/omnicoder.json` —
  new "omnicoder" theme with a purple-first palette. Kept identical shape
  to upstream `opencode.json` so every syntax / diff / markdown slot
  resolves with no rendering regressions.

### Changed

- `packages/opencode/src/cli/logo.ts`: splash banner now spells
  `omnicoder` in the same block-art style as the upstream banner.
  Marked with `// OMNICODER:` for clean upstream merges.
- `packages/opencode/src/cli/cmd/tui/context/theme.tsx`: default theme
  when no `theme` is set anywhere is now `"omnicoder"` instead of
  `"opencode"`. Users who prefer the upstream look can still pick it from
  the theme picker.
- `packages/opencode/src/cli/cmd/tui/thread.ts`: CLI help describes
  `$0` as "start omnicoder tui" — MIT compliance kept by preserving the
  upstream NOTICE / LICENSE files untouched.

### Rationale for the agent aliases

The built-in `build`, `plan`, `general` agents in opencode never existed
under the Claude Code names `general-purpose` / `Explore`, so whenever a
model paraphrased a Claude-style spawn call (`spawn a general-purpose
subagent…`) opencode rejected it with `Unknown agent type`. Shipping the
aliases as thin markdown files that route to equivalent tools makes
cross-trained models Just Work without retraining.

## [5.0.0-alpha.3] — 2026-04-18

Per-phase model routing. Ship a catalogue of presets (balanced / quality /
cheap / nim-free / mixed-nim-anthropic / …) and a tiny CLI that patches
the `agent` block in the user's `opencode.jsonc` — a specific model per
phase without re-pinning the whole TUI.

### Added

- `packages/omnicoder/src/routing/preset.ts`: JSONC-aware editor that finds
  the top-level `"agent"` block, replaces just its value, and preserves
  every comment, MCP server and plugin entry around it. Writes a `.bak`
  next to the file on every apply so reverts are copy-paste away.
- `.omnicoder/routing-presets.json`: ships 7 curated presets covering the
  common provider mixes (Anthropic only, NVIDIA NIM free tier, MiniMax
  Anthropic-compat, mixed NIM+Anthropic for bulk+reasoning).
- `bin/omnicoder-routing` (POSIX) and `bin/omnicoder-routing.ps1` (Windows)
  — thin wrappers that locate `preset.ts` and invoke it with bun. A tiny
  `omnicoder-routing.cmd` forwarder is generated at install time so the
  command works from both PowerShell and CMD.
- `/routing` slash command — `list | get | apply <name> | off`, executes
  the shell wrapper verbatim so the output is the colourful script
  response instead of a paraphrase from the model.
- 5 new tests in `test/routing-preset.test.ts` (JSONC editing with
  comments, fresh insertion when the block is missing, default reset,
  unknown-preset error messaging). Suite now 53/53.

### Changed

- `scripts/install.sh`: installs the new `omnicoder-routing` wrapper and
  copy-if-missing seeds `routing-presets.json` into `~/.omnicoder/`.
- `scripts/install-windows.ps1`: installs `omnicoder-routing.ps1`,
  generates a sibling `.cmd` forwarder, seeds the presets file under
  `%USERPROFILE%\.omnicoder\`.
- `scripts/uninstall.sh` & Windows uninstall block: remove every
  `omnicoder-routing*` artefact alongside the main wrapper.

## [5.0.0-alpha.2] — 2026-04-18

Performance + ergonomics pass. Router is 22× faster on the hot path, the
shipped config no longer hijacks the model the user picked in `/models`,
and a one-shot Windows bootstrap script gets a fresh machine from zero to
running in a single command.

### Performance

- Router warm p50: **23 ms → 0.71 ms** (~32× faster) over 361 indexed
  assets. TF is pre-computed at build time; `bm25()` iterates query terms
  instead of the full doc vocabulary; top-3 selection is a streaming O(n)
  scan instead of sort+slice.
- Router cold p50 **from disk**: **126 ms → 77 ms** (-38%) via smaller
  payload (doc body cap reduced from 2000B to 900B → on-disk index
  **2.6 MB → 1.2 MB**, -53%) and native `Bun.file().json()` when the plugin
  runs under Bun.
- Full pipeline (50 tool calls × 6 hooks) wall clock: **1303 ms → 68 ms**
  (-94.8% end-to-end) — below the v4 TSV baseline of 2000 ms.
- Background warmup: `getIndex()` fires on plugin init so the first user
  prompt never pays the build cost.
- Disk cache lives at `$XDG_CACHE_HOME/omnicoder/router-index.json`,
  keyed by mtime+count of the source dirs. Opt out with
  `OMNICODER_ROUTER_NOCACHE=1`.

### Fixed

- `.omnicoder/opencode.jsonc` no longer pins `build`, `plan`, `general`
  agents to `nvidia-nim/minimaxai/minimax-m2.7`. Model selected in
  `/models` (or `-m`) now sticks across messages; agent overrides are
  opt-in and documented.
- Legacy `~/.omnicoder/.env` (from v4) is now loaded by the wrapper in
  addition to `~/.omnicoder/env`, with `set -a` so provider keys reach
  opencode without a manual rename. Fixes
  `Unauthorized: Header of type authorization was missing` on fresh v4→v5
  upgrades.
- `test/bin-wrapper.test.ts` spawns via `bash` on Windows — Node's
  `spawnSync` cannot `CreateProcess` a shebang-only POSIX script. Repairs
  the 3 bin-wrapper failures visible only on `windows-latest`.
- `/personality` command now executes `~/.omnicoder/scripts/personality.sh`
  and echoes its output verbatim instead of dumping the command markdown.

### Added

- `scripts/bootstrap-windows.ps1` — one-shot Windows bootstrap. Checks
  PowerShell version, installs Node LTS / Git / GitHub CLI via winget,
  runs `gh auth login`, purges legacy v4 / Qwen Code / stale opencode
  state (with automatic memory backup to `%TEMP%`), clones the repo,
  runs `install-windows.ps1`, prompts for `NVIDIA_API_KEY` with masked
  input, persists it to User scope, and verifies with `omnicoder doctor`
  in a refreshed child shell.
  - Flags: `-Yes`, `-SkipCleanup`, `-KeepMemory`, `-NvidiaApiKey`,
    `-RepoDir`, `-DryRun`.
  - Safe by default: refuses to run as admin, only touches the user
    profile + User PATH, every destructive step confirms unless `-Yes`.
- Dedicated `uniq()` pass on query tokens so repeated words in the prompt
  don't over-weight matches.

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
