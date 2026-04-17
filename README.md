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

## Features

- **168 agentes** en 15 categorías (engineering, marketing, design, testing, game dev, specialized, etc).
- **193 skills** auto-invocables por router + skills externas vía `npx skills add`.
- **19 hooks** cognitivos: security, learning, verification, failover.
- **Memoria dual adaptativa**: episódica (trajectories, learned, causal-edges) + semántica (patterns, reflections, stats).
- **Router BM25** con enforcement HARD/SOFT/HINT y feedback loop de 3+ ignores.
- **Verificación obligatoria** de subagents con bloque `<verification>` + validación mtime/tests.
- **Multi-provider nativo** con switch en caliente y failover automático (429/503/timeout).
- **v4.3 dispatcher consolidado**: 6 hooks PostToolUse en uno, latencia de 340ms → 50ms.

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
