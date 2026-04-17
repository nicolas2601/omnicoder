<div align="center">

# ⚡ OmniCoder

**Tu terminal, 168 expertos. Cero suscripciones.**

Extensión cognitiva para [Qwen Code CLI](https://github.com/QwenLM/qwen-code) con memoria dual, router adaptativo y verificación automática de subagents.

![version](https://img.shields.io/badge/version-4.3-blue?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square)
![platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey?style=flat-square)
![agents](https://img.shields.io/badge/agents-168-green?style=flat-square)
![skills](https://img.shields.io/badge/skills-193-green?style=flat-square)
![hooks](https://img.shields.io/badge/hooks-19-orange?style=flat-square)
![commands](https://img.shields.io/badge/commands-21-purple?style=flat-square)

</div>

---

## What is OmniCoder?

OmniCoder convierte tu CLI en un entorno con 168 agentes especializados, 193 skills, 19 hooks y 21 slash commands. Sistema cognitivo completo: memoria dual (episódica + semántica), router con enforcement adaptativo basado en BM25 + bigramas, destilación automática de patrones, y verificación obligatoria de subagents. Model-agnostic: funciona con NVIDIA NIM, Gemini, MiniMax, DeepSeek, OpenRouter u Ollama.

## Quick Start

```bash
git clone https://github.com/nicolas2601/omnicoder.git && cd omnicoder && chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh
```

Luego lanza:

```bash
omnicoder
```

Guía completa en [docs/getting-started.md](./docs/getting-started.md).

## ✨ Features

- 🧠 **168 agentes especializados** — engineering, marketing, design, game-dev, testing, sales y 9 categorías más.
- 🎯 **193 skills instalables** — React, Expo, SEO, frontend-design, maestro, playwright y auto-invocación por router.
- ⚡ **Router híbrido BM25 + bigramas** — matching inteligente de skills/agentes por prompt con enforcement HARD/SOFT/HINT.
- 🔄 **Sistema cognitivo v4** — memoria dual (episódica + semántica), auto-destilación de patterns, causal-edges y reflections.
- 🛡️ **Verificación de subagents** — contrato `<verification>` obligatorio post-Task con validación mtime/tests.
- 🎭 **Personalidades viltrumitas** — 6 alter-egos estilo *Invincible* (Omni-Man, Conquest, Thragg, Anissa, Cecil, Immortal). Solo cambia el tono, no la calidad.
- 🪝 **20 hooks adaptativos** — PreTool, PostTool, UserPrompt, SessionStart, Stop con dispatcher consolidado.
- 🔀 **21 slash commands** — `/review`, `/ship`, `/audit`, `/handoff`, `/personality`, `/memory` y más (ver [docs/commands.md](./docs/commands.md)).
- 📦 **Multi-provider nativo** — NVIDIA NIM, MiniMax, Gemini, DeepSeek, OpenRouter, Ollama con failover automático (429/503/timeout).
- 💾 **Backups con dedup + auto-prune + pin** — nunca pierdes memoria entre upgrades.
- 🪟 **Soporte Windows real** — CMD nativo, PowerShell 5.1+/7+, Git Bash con fallback `flock` vía `mkdir` atómico.
- 🚀 **Performance optimizada** — 6.3x más rápido que v4.2, −83.8 % tokens inyectados por prompt.
- 🧪 **CI/CD completo** — GitHub Actions con `shellcheck` + `bats` + test de instalación en runner `windows-latest`.

## 📜 What's new in each version

### v4.3.2 (Unreleased)

> **Release theme**: Windows-ready · tokens a la mitad · personalidades

- 🎭 **Nueva feature `/personality`** — 6 alter-egos viltrumitas (Omni-Man, Conquest, Thragg, Anissa, Cecil, Immortal). Subcomandos `set`, `get`, `list`, `off`, `random`. Persistente entre sesiones vía `~/.omnicoder/.personality`. Hook `personality-injector.sh` con 4 ms de overhead cuando está inactivo.
- 🪟 **Windows CMD nativo** — reescritos `install-windows.bat`, `install-windows.ps1`, `omnicoder.ps1`; nuevo `omnicoder.cmd`. PATH persistente con `setx`, descarga automática de `jq`, detección de Git Bash, backup automático de `settings.json` + `memory/`. Flags homologadas (`/SKIP_CLI`, `/FORCE`, `/DOCTOR`).
- 🔒 **`.env` robusto en wrappers Windows** — ignoran comentados/vacíos, strippean comillas, respetan `$OMNICODER_HOME` y crean `~/.qwen/settings.json` si falta (fix de los timeouts en PowerShell).
- ⚡ **`_flock-compat.sh`** — helper portable: `flock` en Linux/macOS, `mkdir` atómico en Git Bash. Arregla hooks de aprendizaje en Windows.
- 🧠 **`skill-router-lite.sh`** — fast path para UserPromptSubmit: 80 % de prompts resueltos con 0–15 bytes inyectados. Delega al router completo solo cuando hay tech nueva o prompt >100 palabras.
- 📉 **Token optimization pass (−60 % a −70 %)** — `OMNICODER.md` 231→55 líneas (−78 %), `memory-loader.sh` de 2500→1200 chars, `skills-index.tsv` de 64 KB→20 KB, header `[CONTEXTO PERSISTENTE]` reducido a `[MEM]`.
- 💰 **`token-budget.sh`** — SessionStart hook que avisa si el promedio de las últimas 10 sesiones supera 15k tokens/tarea.
- 📚 **Docs ampliadas** — [docs/architecture.md](./docs/architecture.md) con hooks + memoria + presupuesto; [docs/skills.md](./docs/skills.md) con catálogo por dominio.

### v4.3.0 — 2026-04-17

> **Release theme**: performance overhaul

- ⚡ **Dispatcher consolidado** — 6 hooks `PostToolUse` unificados en `post-tool-dispatcher.sh`. **5.2× speedup** (380 ms → 73 ms por tool call).
- 🕒 **Skill-router cache TTL** extendido de 1h a 24h; rebuild churn drásticamente reducido.
- 📉 `memory-loader.sh` output trimmed de 8000 → 2500 chars para reducir context overhead.
- 🛫 **Early-exit** para prompts conversacionales — se salta el routing cuando no hay match probable.
- 🐛 **Fix crítico en `provider-failover.sh`** — el hook leía `.tool_output` (campo inexistente en el payload del CLI); ahora detecta correctamente `HTTP 429` y el failover se verificó contra NVIDIA, Gemini, DeepSeek, OpenRouter y MiniMax.
- 🎛️ Nuevo flag `OMNICODER_SKIP_NPX` para entornos offline o constrained.
- 🔁 **Stale-while-revalidate** en `npx skills find` — sirve cache al instante y refresca en background.

### v4.2.0 — 2026-04-15

> **Release theme**: Windows parity + tracker fixes

- 🪟 Paridad Windows en installers (`install-windows.ps1`) matching el feature set Linux/macOS.
- 🏷️ `patch-branding.sh` — normaliza strings de branding en installers y configs generados.
- 🐛 **Fix skill-usage-tracker** — leía `last-suggestions.json` (plural) mientras el router escribía `last-suggestion.json` (singular). Ahora los counters de ignores avanzan correcto.
- 🐛 **Fix `jq tostring`** en stats pipeline que corrompía agregaciones numéricas en `claude-tool-stats.json`.
- ⚛️ Counters entre `ignored-skills.md` y `claude-tool-stats.json` ahora se actualizan atómicamente.

### v4.1.0 — 2026-04-10

> **Release theme**: sistema cognitivo v4

- 🧠 **Cognitive system v4** — 5 nuevos learning hooks: `error-learner`, `success-learner`, `skill-usage-tracker`, `causal-learner`, `reflection`.
- 🎯 **Hybrid scoring** en el skill router — combina **BM25** y similitud de bigramas sobre el índice skill/agent.
- 💾 **Dual memory model** — episódica (conversation-level) + semántica (long-term), cableado en router y learning hooks.

### v4.0.0 — 2026-04-01

> **Release theme**: rebrand + multi-provider + verificación obligatoria

- 🏷️ **Rebrand** — _Qwen Con Poderes_ → **OmniCoder**. Repo, package name, binary, install paths y docs actualizados. Shim de compatibilidad mantiene configs legacy un ciclo minor.
- 📦 **Multi-provider support** — NVIDIA NIM, Gemini AI Studio, DeepSeek, OpenRouter, MiniMax.
- 🛡️ **Bloque `<verification>` obligatorio** en cada respuesta de subagent; bloques faltantes o malformados disparan retry.

Historial completo con detalle granular en [CHANGELOG.md](./CHANGELOG.md).

## Documentation

| Documento | Contenido |
|-----------|-----------|
| [getting-started.md](./docs/getting-started.md) | Prerequisitos, instalación, primera sesión |
| [architecture.md](./docs/architecture.md) | Sistema cognitivo v4, memoria dual, router, niveles de complejidad, verificación |
| [hooks.md](./docs/hooks.md) | Los 19 hooks, eventos, propósito y ejecución sync/async |
| [agents.md](./docs/agents.md) | Catálogo por categoría, cómo usar, cómo crear un agente propio |
| [skills.md](./docs/skills.md) | Skills vs agentes, invocación, crear skill propia |
| [commands.md](./docs/commands.md) | Los 21 slash commands con ejemplos |
| [providers.md](./docs/providers.md) | NVIDIA, Gemini, MiniMax, DeepSeek, Ollama: setup y failover |
| [troubleshooting.md](./docs/troubleshooting.md) | Scroll bug, hooks en Windows, rate limits, lentitud |

## Supported Providers

| Provider | Free tier | Prompt cache | Estado |
|----------|-----------|--------------|--------|
| NVIDIA NIM | 40 RPM (créditos finitos) | No | Principal free |
| Google Gemini | 1500 req/día | Sí implícito | Secundario free |
| MiniMax | Limitado | Dudoso | $10/mes plan |
| DeepSeek | Limitado | Sí | Más barato pagado |
| OpenRouter | Por modelo | Depende upstream | Agregador |
| Ollama | Local ilimitado | N/A | Fallback offline |

Detalles y setup en [docs/providers.md](./docs/providers.md).

## Contributing

Se aceptan PRs con nuevos agentes, skills y hooks. Revisa las guías de formato en [docs/agents.md](./docs/agents.md), [docs/skills.md](./docs/skills.md) y [docs/hooks.md](./docs/hooks.md). Para cambios grandes, abre un issue primero.

## License

[MIT](./LICENSE). El CLI base ([Qwen Code](https://github.com/QwenLM/qwen-code)) está bajo Apache 2.0 por Alibaba/Qwen; se mantiene atribución para el código upstream.

## Credits

- [Qwen Code](https://github.com/QwenLM/qwen-code) — CLI base (Apache 2.0).
- [Claude Code](https://claude.com/claude-code) — convenciones de hooks, skills y `settings.json`.
- [Gentleman.Dots](https://github.com/Gentleman-Programming) — influencia en el estilo README.
- [Ruflo](https://github.com/ruvnet/ruflo) — inspiración para router cognitivo.

Creado por [@nicolas2601](https://github.com/nicolas2601).
