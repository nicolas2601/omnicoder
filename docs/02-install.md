# 02 · Instalación

## Recomendado: `npm install -g` (Linux / macOS / Windows)

```bash
npm install -g @nicolas2601/omnicoder@alpha
```

Eso baja:
- El wrapper `@nicolas2601/omnicoder` con 172 agents + 29 commands + theme + routing presets como assets bundleados.
- `opencode-ai` upstream (per-platform binary: linux-x64, linux-arm64, darwin-x64, darwin-arm64, windows-x64, windows-arm64).
- `@nicolas2601/omnicoder-core` plugin TS (skill router, security guard, memory loader, personality injector, token budget, tool dispatcher, provider failover).

Verificar:

```bash
omnicoder --version
# omnicoder 5.0.0-alpha.11
#   runtime: opencode-ai 1.14.18
#   node:    v20.20.2
#   platform: linux x64
#   binary:  ...
```

Primera ejecución:

```bash
omnicoder
# [omnicoder] seeded 172 agents + 29 commands → ~/.config/opencode/
```

En Windows siembra en `%APPDATA%\opencode\`.

### Pre-requisitos

- **Node.js 18+** (recomendado 20 LTS). Bajar de https://nodejs.org/.
- **Windows**: PowerShell 5.1+ o Git Bash. El wrapper es puro JS, no shell-dependent.

### API key (al menos una)

```bash
export NVIDIA_API_KEY="nvapi-..."      # free tier 40 RPM con MiniMax M2.7
export ANTHROPIC_API_KEY="sk-ant-..."  # Claude
export MINIMAX_API_KEY="..."           # MiniMax direct
export DASHSCOPE_API_KEY="..."         # Alibaba Qwen
export OPENAI_API_KEY="..."            # OpenAI
```

Windows PowerShell:
```powershell
[Environment]::SetEnvironmentVariable("NVIDIA_API_KEY", "nvapi-...", "User")
# reabrir terminal para que tome efecto
```

### Auto-update

El wrapper chequea el registry cada 24h al lanzar la TUI (TTY-only, cacheado). Si hay versión nueva imprime un hint. Para actualizar:

```bash
omnicoder update
# o: npm install -g @nicolas2601/omnicoder@alpha
```

Deshabilitar el chequeo: `export OMNICODER_NO_UPDATE_CHECK=1`.

### Desinstalar

```bash
npm uninstall -g @nicolas2601/omnicoder
# opcional: borrar assets sembrados
rm -rf ~/.config/opencode/agent ~/.config/opencode/command
rm -rf ~/.omnicoder
```

Windows PowerShell:
```powershell
npm uninstall -g @nicolas2601/omnicoder
Remove-Item -Recurse -Force "$env:APPDATA\opencode\agent", "$env:APPDATA\opencode\command"
Remove-Item -Recurse -Force "$env:USERPROFILE\.omnicoder"
```

---

## Alternativa: source build (para contribuidores)

```bash
git clone https://github.com/nicolas2601/omnicoder.git ~/omnicoder-v5
cd ~/omnicoder-v5
bun install --frozen-lockfile
bun run dev                # lanza la TUI desde el source con live reload de cambios
```

Los cambios al plugin (`packages/omnicoder/`) requieren rebuild con `bun --cwd packages/omnicoder run build` antes de publicar. Los cambios al TUI (`packages/opencode/`) son live bajo `bun run dev`.

---

## Troubleshooting rápido

| Síntoma | Causa probable | Fix |
|---|---|---|
| `omnicoder: command not found` | npm prefix no está en PATH | `npm config get prefix` → agregar `<prefix>/bin` al PATH |
| `Error: Failed to change directory to .../update` | Wrapper viejo sin soporte `update` | `npm install -g @nicolas2601/omnicoder@alpha --force` |
| Opencode abre en `~/omnicoder-v5/packages/opencode` | Wrapper legacy del repo viejo | `npm install -g @nicolas2601/omnicoder@alpha --force` (reemplaza el wrapper por el de npm) |
| `/personality` imprime texto en vez de abrir picker | `personality.md` viejo quedó cacheado | `omnicoder seed --force` (borra el markdown deprecated) |
| Respuestas como "Soy OpenCode" tras elegir persona | Plugin no cargado | Verificar que el config tenga `"plugin": ["@nicolas2601/omnicoder-core"]`. `omnicoder seed --force` regenera el default. |

---

## Antiguo flujo (source clone + bootstrap) — DEPRECATED

El `scripts/bootstrap-windows.ps1` y `scripts/install.sh` todavía funcionan
para desarrollo local pero **no son la ruta recomendada para usuarios finales**. Usá `npm install -g @nicolas2601/omnicoder@alpha`.
