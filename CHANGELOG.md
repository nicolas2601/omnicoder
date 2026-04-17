# Changelog

All notable changes to **OmniCoder** will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Windows support**: reescritos `install-windows.bat`, `install-windows.ps1`, `omnicoder.ps1` y agregado `omnicoder.cmd` para funcionar al 100% en CMD nativo, PowerShell 5.1+/7+, y Git Bash. El instalador CMD ahora descarga `jq` automaticamente si falta, verifica `bash` en PATH (con instrucciones para Git Bash), persiste `OMNICODER_HOME` y extiende el PATH de usuario via `setx`. Flags homologadas entre plataformas: `/SKIP_CLI` (`-SkipCli`), `/FORCE` (`-Force`), `/DOCTOR` (`-Doctor`), `/HELP` (`-?`). Exit codes normalizados (0 exito, 1 prereq faltante, 2 path invalido, 3 error de copia). Backup automatico de `settings.json` + `memory/` antes de sobreescribir.
- **Hooks en Git Bash Windows**: los hooks de aprendizaje (`error-learner`, `success-learner`, `causal-learner`, `skill-usage-tracker`) y el `post-tool-dispatcher` dependian de `flock(1)`, que no existe en Git Bash. Se agrega `hooks/_flock-compat.sh` que provee `oc_locked_append`, `oc_with_lock` y `oc_locked_heredoc` con fallback basado en `mkdir` (atomico en NTFS). Los `flock`-branches se conservan como fallback adicional.
- **Carga de `.env` en wrappers Windows**: `omnicoder.cmd`/`.bat`/`.ps1` ahora ignoran lineas comentadas (`#`) y vacias, strippean comillas de los valores, respetan `$OMNICODER_HOME` y crean `~/.qwen/settings.json` (si falta) apuntando a los hooks de OmniCoder. Antes fallaban silenciosamente y qwen arrancaba sin hooks, causando los timeouts reportados en PowerShell.

### Added

- **Personalidades viltrumitas (feature chistosa, v4.3.2)**: nuevo comando `/personality` que activa alter-egos del universo Invincible. 6 personalidades soportadas: `omni-man` (arrogante paternal, "¡Piensa Mark, PIENSA!"), `conquest` (psicopata violento con risas maniaticas), `thragg` (emperador viltrumita, frio imperial), `anissa` (sarcastica fria), `cecil` (Cecil Stedman pragmatico, anti-viltrumita), `immortal` (solemne epico con referencias historicas). Subcomandos: `set <nombre>`, `get`, `list`, `off`, `random`. El trabajo tecnico sigue siendo impecable; solo cambia el tono. Persistente entre sesiones via `~/.omnicoder/.personality`. Implementado con `scripts/personality.sh` (CLI), `hooks/personality-injector.sh` (UserPromptSubmit hook, 4ms overhead cuando inactivo), `commands/personality.md` (slash command doc).
- `hooks/skill-router-lite.sh`: fast path para UserPromptSubmit. 80% de prompts se resuelven con 0-15 bytes inyectados. Delega a `skill-router.sh` solo cuando hay tech nueva o prompt >100 palabras.
- `hooks/_flock-compat.sh`: helper portable para locking de archivos en hooks (flock en Linux/macOS, mkdir fallback en Git Bash Windows).
- `scripts/omnicoder.cmd`: wrapper CMD estandar para Windows (reemplaza `omnicoder.bat`, que ahora delega al .cmd para backward-compat).
- `hooks/token-budget.sh`: SessionStart hook que monitorea `~/.omnicoder/logs/token-usage.jsonl` y advierte si el promedio de ultimas 10 sesiones supera 15k tokens/tarea.
- `docs/architecture.md` ampliado con hooks, memoria y presupuesto de tokens; `docs/skills.md` con catalogo por dominio.

### Changed

- **Token optimization pass (-60% a -70% input tokens)**:
  - `OMNICODER.md`: 231 lineas / 10.758 B -> ~55 lineas / ~2.400 B (~-78%). Detalles movidos a `docs/architecture.md` y `docs/skills.md`.
  - `memory-loader.sh`: `MAX_TOTAL_CHARS` 2500 -> 1200, `MAX_LINES` 25 -> 12. Solo carga `patterns.md` + `feedback.md`; `learned.md`, `trajectories.md`, `causal-edges.md` quedan bajo demanda via `/memory`.
  - Header verboso "[CONTEXTO PERSISTENTE]..." reducido a marker `[MEM]`.
  - `build-skill-index.sh` y `skill-router.sh`: descripciones comprimidas con strip de stopwords (EN+ES) y truncate a 80 chars. `skills-index.tsv` 64 KB -> ~20 KB.
  - `settings.json` UserPromptSubmit ahora apunta a `skill-router-lite.sh`.

## [4.3.0] - 2026-04-17

### Added

- Environment flag `OMNICODER_SKIP_NPX` to bypass `npx` lookups in constrained or offline environments.
- Stale-while-revalidate caching layer for `npx skills find`, serving cached entries instantly while refreshing in background.

### Changed

- **Performance overhaul**: consolidated 6 separate `PostToolUse` hooks into a single `post-tool-dispatcher.sh`, yielding a **5.2x speedup** (380 ms → 73 ms per tool call).
- Skill-router cache TTL extended from 1 hour to 24 hours, drastically reducing index rebuild churn.
- `memory-loader.sh` output trimmed from 8000 to 2500 characters to lower context overhead.
- Early-exit path added for conversational prompts, skipping expensive routing when no skill/agent match is likely.

### Fixed

- **Critical** `provider-failover.sh` bug: the hook was reading `.tool_output` (a field that never existed in the Qwen Code CLI payload), so `HTTP 429` responses from providers were never detected and failover never triggered. Now reads the correct payload field and failover is verified against NVIDIA NIM, Gemini, DeepSeek, OpenRouter, and MiniMax.

## [4.2.0] - 2026-04-15

### Added

- `patch-branding.sh` script to normalize branding strings across installers and generated configs.
- Windows parity in installers (`install-windows.ps1`) matching the Linux/macOS feature set.

### Fixed

- `skill-usage-tracker` was reading `last-suggestions.json` (plural) while the router wrote `last-suggestion.json` (singular); tracker now reads the correct filename and ignore-counters advance as expected.
- `jq` `tostring` bug in the stats pipeline that corrupted numeric aggregations in `claude-tool-stats.json`.
- Inconsistent counters between `ignored-skills.md` and `claude-tool-stats.json` are now updated atomically.

## [4.1.0] - 2026-04-10

### Added

- Cognitive system **v4**: five new learning hooks — `error-learner`, `success-learner`, `skill-usage-tracker`, `causal-learner`, and `reflection`.
- Hybrid scoring in the skill router combining **BM25** and bigram similarity over the skill/agent index.
- Dual memory model: episodic (conversation-level) plus semantic (long-term) stores, wired into the router and learning hooks.

## [4.0.0] - 2026-04-01

### Added

- Multi-provider support: **NVIDIA NIM**, **Gemini AI Studio**, **DeepSeek**, **OpenRouter**, and **MiniMax**.
- Mandatory `<verification>` block in every subagent response; missing or malformed blocks trigger a retry.

### Changed

- **Project rebrand** from _Qwen Con Poderes_ to **OmniCoder**. Repository, package name, binary, install paths, and documentation were all updated. A compatibility shim keeps legacy configurations working for one minor cycle.

[Unreleased]: https://github.com/nicolas2601/omnicoder/compare/v4.3.0...HEAD
[4.3.0]: https://github.com/nicolas2601/omnicoder/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/nicolas2601/omnicoder/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/nicolas2601/omnicoder/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/nicolas2601/omnicoder/releases/tag/v4.0.0
