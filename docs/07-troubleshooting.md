# 07 · Troubleshooting

Tabla de síntomas comunes y fixes.

---

## Instalación

| Síntoma | Causa | Fix |
|---|---|---|
| `scripts/install.sh: Permission denied` | Permisos del filesystem en `/usr/local/bin` | `PREFIX=$HOME/.local bash scripts/install.sh --yes --no-sudo` |
| `npm not found` | Node no instalado | Instalar Node 18 LTS desde [nodejs.org](https://nodejs.org) o via `nvm` |
| `gh: command not found` (warning) | `gh` CLI ausente | Ignorable — installer cae a `curl` automáticamente |
| `engram asset missing after download` | GitHub Releases API tumbado o geo-blockeado | `ENGRAM_SKIP=1 bash scripts/install.sh --yes` y seguir sin MCP |
| SHA-256 mismatch en Engram | Asset upstream rotó sin actualizar pin | Verificar nuevo hash, exportar `ENGRAM_SHA256_LINUX_X64=<hash>` y reintentar |
| Windows: `omnicoder` no está en PATH | Shell actual no recargó la variable | Cerrar y abrir nueva PowerShell |
| Windows: `setx: truncation warning` | `setx` truncó el PATH en 1024 chars | Ya resuelto — el installer usa `[Environment]::SetEnvironmentVariable`, no `setx` |

## Runtime

| Síntoma | Causa | Fix |
|---|---|---|
| `opencode: command not found` al correr `omnicoder` | npm global bin no está en PATH | `export PATH="$(npm root -g)/../bin:$PATH"` o `npm config get prefix` |
| `[miss] opencode binary` en doctor | npm global bin no vinculado | `npm install -g opencode-ai@latest` |
| TUI arranca pero `/provider` dice "none" | Ninguna API key exportada | `export NVIDIA_API_KEY=...` en `~/.bashrc` / `~/.zshrc` |
| TUI cuelga en "loading skills" | Directorio `~/.omnicoder/skills/` corrupto | `rm -rf ~/.omnicoder/skills && omnicoder install-skills` |
| Error `ENOSPC: too many open files` | Límite del OS bajo | `ulimit -n 10240` antes de arrancar |
| `node-pty` falla en macOS | Binario no compilado para tu arquitectura | `bun run --cwd packages/opencode fix-node-pty` |
| Windows: UTF-8 garbled | Consola no en UTF-8 | `chcp 65001` antes de `omnicoder` |

## Hooks / plugin

| Síntoma | Causa | Fix |
|---|---|---|
| Skills no se inyectan | Router memoize stale | Borrá `~/.omnicoder/.router-cache/` |
| `security-guard` bloquea un comando legítimo | Whitelist restrictiva | Agregá el binario a `omnicoder.security.allowCommands[]` en `opencode.jsonc` |
| Memory-loader inyecta nada | `patterns.md` / `feedback.md` no existen | Crealos en `~/.omnicoder/memory/` aunque sean vacíos |
| Token-budget alerta falsa | Modelo con thinking mode infla tokens | Subí `warnThreshold` en `opencode.jsonc → omnicoder.budget` |
| Provider-failover nunca cambia de provider | Solo una API key exportada | Exportá al menos 2 (ej. `NVIDIA_API_KEY` + `MINIMAX_API_KEY`) |

## CI

| Síntoma | Causa | Fix |
|---|---|---|
| `bun install` falla en GitHub Actions | Cache corrupto | Borrar cache de Actions → re-run |
| Windows runner cuelga 15 min | `robocopy` sin `/R:0 /W:0` (legado) | Ya resuelto — commit `da94e0c` añadió los flags |
| `errorlevel sticky` en CI Windows | `robocopy` per-item acumula rc | Ya resuelto — commit `315dabd` usa 1 llamada sobre dir padre |
| `xcopy` devuelve rc=1 en subdirs vacíos | Comportamiento estándar | Ya mitigado — se prefiere `robocopy`, check `rc < 16` |
| Tests rompen solo en macOS | `fix-node-pty` no corrió | `bun run --cwd packages/opencode fix-node-pty` antes de `test` |

## Sincronización upstream

| Síntoma | Causa | Fix |
|---|---|---|
| Conflictos enormes al mergear upstream | Renombrás strings user-visibles en core opencode | Preferí plugin-layer; si sí tocás core, marcá con `// OMNICODER:` y resolvé a mano |
| `git merge upstream/dev` rompe tests | Cambios de API en plugin protocol | Actualizar `packages/omnicoder/` según nueva API |
| `omnicoder sync-upstream` falla | Branch `dev` con cambios locales | `git checkout dev && git stash && omnicoder sync-upstream` |

## Permisos / security

| Síntoma | Causa | Fix |
|---|---|---|
| "permission denied" al leer `.ssh/config` | Deny list por default (SEC-03) | Esperado. Si querés permitirlo: quitar path de `permission.deny[]` |
| Comando bloqueado por guard pero debería pasar | Pattern match false positive | Reportar issue con el comando exacto; mientras tanto, `omnicoder.security.allowCommands` |
| Secret detectado en prompt falsamente | Regex de JWT/token demasiado agresivo | Ajustar `omnicoder.security.secretPatterns` en config |

---

## Dónde buscar más

- `omnicoder doctor` — primer diagnóstico.
- `omnicoder --omnicoder-version` — versión + core opencode.
- Logs: `~/.omnicoder/logs/*.jsonl`.
- GitHub Issues: <https://github.com/nicolas2601/omnicoder-v5/issues>.
- ADRs en `docs/adr/` — decisiones arquitectónicas.
