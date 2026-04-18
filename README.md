# OmniCoder v5

> Fork profesional de [`sst/opencode`](https://github.com/sst/opencode) con plugin propio `@omnicoder/core` que añade skill-router BM25, security guard, token budget, provider failover y memoria compartida. El fork es **tuyo de punta a punta**: wrappers `omnicoder` (POSIX + Windows), 167 agentes, 193 skills, CI cross-OS y CHANGELOG gateado.

```
  ___                  _  ____          _
 / _ \ _ __ ___  _ __ (_)/ ___|___   __| | ___ _ __
| | | | '_ ` _ \| '_ \| | |   / _ \ / _` |/ _ \ '__|
| |_| | | | | | | | | | | |__| (_) | (_| |  __/ |
 \___/|_| |_| |_|_| |_|_|\____\___/ \__,_|\___|_|     v5
```

- Base: `sst/opencode@1.4.11` (MIT)
- Runtime: `~/.omnicoder/` (skills, agents, memory, config)
- Plugin: `@omnicoder/core` — 6 hooks TypeScript, 45 tests, <200 ms suite
- Owner: `nicolas2601 <nm5571762@gmail.com>`

## Instalación en un solo comando

Linux, macOS **y Windows (Git Bash)** — el mismo comando:

```bash
curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/setup.sh | bash
```

El script hace todo: detecta OmniCoder v4 (Qwen Code) si existe y la desinstala con backup, clona el repo, instala `opencode` y `engram`, copia los wrappers, siembra `~/.omnicoder/` y `opencode.jsonc`, corre `doctor` y los tests + benchmarks.

Desinstalar (v4 + v5 completo) en un solo comando:

```bash
curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/uninstall.sh | bash
# purga total (memoria + config + repo): añadir -s -- --purge-all
```

Verificación:

```bash
omnicoder --omnicoder-version
omnicoder doctor
omnicoder
```

> Windows: correr el comando **dentro de Git Bash** (viene con Git for Windows).

## Providers soportados (una API key mínima)

```bash
export NVIDIA_API_KEY=...      # NVIDIA NIM · MiniMax M2.7 + Qwen3 Coder (free 40 RPM)
export MINIMAX_API_KEY=...     # MiniMax direct (Anthropic-compat, prompt caching nativo)
export DASHSCOPE_API_KEY=...   # Alibaba Qwen Max
export ANTHROPIC_API_KEY=...   # Claude
export OPENAI_API_KEY=...      # OpenAI GPT
```

Failover automático con cool-down 60 s. Matriz completa en [`docs/03-providers.md`](docs/03-providers.md).

## Documentación

| Tema | Archivo |
|---|---|
| Quickstart (5 min, Linux/mac/Win) | [`docs/01-quickstart.md`](docs/01-quickstart.md) |
| Instalación detallada + desinstalación | [`docs/02-install.md`](docs/02-install.md) |
| Providers y failover | [`docs/03-providers.md`](docs/03-providers.md) |
| Skills y agentes (193 + 167) | [`docs/04-skills-agents.md`](docs/04-skills-agents.md) |
| Hooks del plugin `@omnicoder/core` | [`docs/05-hooks.md`](docs/05-hooks.md) |
| Benchmarks y QA | [`docs/06-benchmarks.md`](docs/06-benchmarks.md) |
| Troubleshooting | [`docs/07-troubleshooting.md`](docs/07-troubleshooting.md) |
| Control del CLI (cómo modificar cualquier parte) | [`docs/control-del-cli.md`](docs/control-del-cli.md) |
| Migración desde v4 (Qwen Code) | [`docs/MIGRATION.md`](docs/MIGRATION.md) |
| Uninstall | [`docs/uninstall.md`](docs/uninstall.md) |
| ADRs (decisiones de arquitectura) | [`docs/adr/`](docs/adr) |

## Estado

| Métrica | Valor |
|---|---|
| Versión actual | `5.0.0-alpha.1` |
| Tests | **45** (21 unit + 24 integration, Bun test) |
| CI | 3-OS matrix (Ubuntu + macOS + Windows) · verde |
| Assets portados | **193 skills + 167 agents + 5 ADRs** |
| Hooks | 6 TS plugins (router, security, memory, budget, dispatcher, failover) |
| SEC-01 | guard whitelist bypass cerrado (`&&` `;` `\|` `$()` backticks) |
| SEC-03 | denylist extendido: `.ssh/`, `.aws/`, `.gcp/`, `.azure/`, `.kube/`, `.docker/`, `.npmrc`, `.netrc` |
| SEC-05 | Engram SHA-256 pinning en installer |
| SEC-06 | atribución MIT a SST en LICENSE + NOTICE |

## Arquitectura (alto nivel)

```
omnicoder-v5/
├── bin/                         wrappers del producto (sh · cmd · ps1)
├── packages/
│   ├── opencode/                base upstream (MIT)
│   └── omnicoder/               plugin propio TypeScript
├── .opencode/
│   ├── agent/                   167 agentes
│   └── skills/                  193 skills
├── docs/                        8 docs temáticos + ADRs + MIGRATION
├── scripts/                     install.sh · install-windows.ps1 · port-v4-assets.ts
└── .github/workflows/           CI 3-OS · release on tag · PR gate
```

Detalle en [`docs/control-del-cli.md`](docs/control-del-cli.md).

## Contribuir

```bash
bun install --frozen-lockfile
bun run --cwd packages/omnicoder typecheck
bun run --cwd packages/omnicoder test
```

Reglas en [`CONTRIBUTING.md`](CONTRIBUTING.md). El workflow `omnicoder-pr.yml` gatea que cada PR toque `CHANGELOG.md`.

## Licencia

MIT — ver [`LICENSE`](LICENSE) y [`NOTICE`](NOTICE). Atribución dual:
original de SST (opencode) y derivado de nicolas2601 (omnicoder).

## Soporte

- Issues: <https://github.com/nicolas2601/omnicoder/issues>
- Specs internas: `/home/nicolas/omnicoder-v5-specs/`
