# Migrar de OmniCoder v4 (Qwen Code) → v5 (Opencode fork)

Este documento describe cómo llevar tu instalación actual de OmniCoder v4
(construida sobre **Qwen Code CLI**) a OmniCoder v5 (fork directo de
**Opencode** con plugin `@omnicoder/core`).

> **TL;DR** — v5 preserva todos tus skills, agentes y memoria. Cambian las
> rutas de configuración y el binario de runtime (`qwen` → `opencode`
> detrás del wrapper `omnicoder`). Un script hace el 95% del trabajo.

---

## 1. Por qué se hizo el cambio

| | v4 (Qwen Code) | v5 (Opencode fork) |
|---|---|---|
| Base CLI | `@qwen-code/qwen-code@0.14.5` (fork cerrado de Claude Code) | `sst/opencode@1.4.11` (fork directo, **tuyo**) |
| Control sobre el CLI | Solo hooks externos. Parches imposibles. | Código completo — podés modificar cualquier parte. |
| Idioma de hooks | Bash + jq (6 forks por evento) | TypeScript tipado (1 proceso, `@opencode-ai/plugin` API) |
| Memoria | Markdown en disco | Markdown **+** Engram MCP (vector DB) como primer-class |
| Tests | Sin suite unificada | 45 tests (21 unit + 24 integration), <200 ms |
| Windows | Instalador + wrappers `.bat`/`.ps1` | Instalador PS1 + wrappers `.cmd`/`.ps1` (**probado en CI**) |
| CI | GitHub Actions (3 OS) | GitHub Actions (3 OS) + `bun install --frozen-lockfile` gate |
| Auditoría seguridad | `security-guard.sh` solo prefijos | TS guard con bypass coverage (SEC-01 cerrado) |

---

## 2. Precheck

```bash
# v4
omnicoder --version       # debería decir 4.3.x
qwen --version             # debería existir
ls ~/.omnicoder/           # debería existir con agents/ skills/ memory/
```

Si alguno falta, tu v4 ya no está funcional y podés ir directo a una
**instalación limpia de v5** (sección 5).

---

## 3. Respaldar v4 (recomendado)

```bash
# bash
tar czf ~/omnicoder-v4-backup-$(date +%Y%m%d).tar.gz \
  ~/.omnicoder ~/.qwen 2>/dev/null || true
ls -lh ~/omnicoder-v4-backup-*.tar.gz
```

```powershell
# PowerShell
$ts = Get-Date -Format "yyyyMMdd"
Compress-Archive -Path "$env:USERPROFILE\.omnicoder","$env:USERPROFILE\.qwen" `
  -DestinationPath "$env:USERPROFILE\omnicoder-v4-backup-$ts.zip" -Force
```

---

## 4. Migración in-place

> Los scripts descubren automáticamente tu v4 y migran en **modo seguro**
> (no pisa nada que ya tengas en `.omnicoder/` de v5).

### Linux/macOS

```bash
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder-v5
bash scripts/install.sh --yes
# v4 sobrevivirá en ~/.omnicoder (compartido). Si querés limpieza total:
bash scripts/migrate-from-v4.sh
```

### Windows

```powershell
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder-v5
pwsh .\scripts\install-windows.ps1 -Yes
# Para mover config de Qwen Code a Opencode:
pwsh .\scripts\migrate-from-v4.ps1
```

### Qué hace la migración

| Dirección | v4 path | v5 path |
|---|---|---|
| Config principal | `~/.qwen/settings.json` | `~/.config/opencode/opencode.jsonc` (Linux/mac) · `%APPDATA%\opencode\opencode.jsonc` (Win) |
| Auth credentials | `~/.qwen/oauth_creds.json` | **borrar** — Opencode usa env-vars (`MINIMAX_API_KEY`, etc.) |
| Hooks | `~/.omnicoder/hooks/*.sh` | reemplazados por plugin TS. Tus shell hooks siguen ejecutables pero no son llamados. |
| Agents | `~/.omnicoder/agents/*.md` | **copiados** a `.opencode/agent/` del repo si clonás; o a `~/.omnicoder/agents/` conservados. |
| Skills | `~/.omnicoder/skills/*` | idem — `.opencode/skills/` dentro del repo, o `~/.omnicoder/skills/`. |
| Memoria | `~/.omnicoder/memory/*.md` | **conservada** tal cual. El plugin `memory-loader` la lee si Engram no está activo. |
| Stats | `~/.omnicoder/claude-tool-stats.json` | conservado, formato compatible con `token-budget` hook. |

### Matriz de hooks

| Hook v4 (shell) | Equivalente v5 (TS) | Notas |
|---|---|---|
| `skill-router.sh` + `-lite.sh` | `packages/omnicoder/src/router/` | BM25 + bigramas, memoize 60 s, **paralelo** |
| `security-guard.sh` | `packages/omnicoder/src/security/` | SEC-01: cierra bypass con `&&` `;` `\|` `$()` backticks |
| `memory-loader.sh` | `packages/omnicoder/src/memory/` | 1200 B cap, skip si Engram activo |
| `token-budget.sh` | `packages/omnicoder/src/budget/` | JSONL rolling avg, alerta >15 k |
| `post-tool-dispatcher.sh` | `packages/omnicoder/src/hooks/tool-dispatcher.ts` | No throws, JSONL logs |
| `provider-failover.sh` | `packages/omnicoder/src/hooks/provider-failover.ts` | 60 s cool-down (mid-session failover → v5.1) |

---

## 5. Instalación limpia (sin v4)

Si preferís no migrar:

```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/install.sh | bash -s -- --yes
```

```powershell
# Windows
iwr -useb https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/install-windows.ps1 | iex
```

---

## 6. Comandos nuevos en v5

| v4 | v5 |
|---|---|
| `omnicoder sync skills` | `omnicoder install-skills` |
| `omnicoder --version` | `omnicoder --omnicoder-version` (también imprime versión del core opencode) |
| `omnicoder doctor` | `omnicoder doctor` (mismo nombre, salida extendida) |
| `omnicoder memory search <q>` | delegado a Engram (`omnicoder memory search <q>`) o lectura de `~/.omnicoder/memory/` |
| *(N/A v4)* | `omnicoder sync-upstream` — merge desde `sst/opencode` |
| *(N/A v4)* | `omnicoder bench` — corre los benchmarks de `packages/omnicoder/bench/` |

---

## 7. Desinstalar v4 completamente (post-migración)

```bash
# Linux/macOS
sudo npm uninstall -g @qwen-code/qwen-code 2>/dev/null || true
rm -rf ~/.qwen
# Conservá ~/.omnicoder — v5 la usa también.
```

```powershell
# Windows
npm uninstall -g @qwen-code/qwen-code 2>$null
Remove-Item -Recurse -Force "$env:USERPROFILE\.qwen" -ErrorAction SilentlyContinue
```

---

## 8. Rollback a v4 si algo sale mal

```bash
bash scripts/install.sh --uninstall --yes
tar xzf ~/omnicoder-v4-backup-*.tar.gz -C ~/
npm install -g @qwen-code/qwen-code@0.14.5
```

---

## 9. Problemas conocidos

- **`bun install` falla con "node-pty not found"** — normal en macOS. Correr
  `bun run --cwd packages/opencode fix-node-pty` y reintentar.
- **`engram` no se baja en el installer** — si tu red bloquea GitHub Releases
  API, exportá `ENGRAM_SKIP=1` al instalar. El plugin `memory-loader` usa
  fallback a markdown local.
- **`omnicoder` no aparece en PATH** después de instalar en Windows — abrir
  una **nueva** terminal. `install-windows.ps1` usa `[Environment]::Set...`
  y no afecta la sesión actual.

---

## 10. Soporte

- Issues: https://github.com/nicolas2601/omnicoder/issues
- Specs internas: `/home/nicolas/omnicoder-v5-specs/`
- ADRs: `docs/adr/ADR-00*`
