# 01 · Quickstart

De cero a `omnicoder` corriendo en menos de 2 minutos.

## Requisitos

- Node.js 18+ (recomendado 20 LTS). https://nodejs.org/
- Una API key de al menos un provider (NVIDIA NIM es free).

## 1 · Instalar

```bash
npm install -g @nicolas2601/omnicoder@alpha
```

Funciona igual en **Linux, macOS y Windows** (PowerShell o Git Bash). El package trae 172 agents + 29 commands + theme morado + routing presets y depende de `opencode-ai` (per-platform binary).

## 2 · API key

```bash
# Linux / macOS
export NVIDIA_API_KEY="nvapi-..."
```

```powershell
# Windows
[Environment]::SetEnvironmentVariable("NVIDIA_API_KEY", "nvapi-...", "User")
# reabrir PowerShell para que tome efecto
```

NVIDIA NIM es free (40 RPM) con MiniMax M2.7. Si preferís Claude: `ANTHROPIC_API_KEY`.

## 3 · Lanzar

```bash
omnicoder
```

Primera ejecución imprime:
```
[omnicoder] seeded 172 agents + 29 commands → ~/.config/opencode/
```

## 4 · Probar

Dentro de la TUI:

```
/personality               # abre picker visual de personas
/themes                    # cambiar tema
/help                      # ver todos los comandos
```

En CLI:

```bash
omnicoder --version        # info completa
omnicoder update           # actualizar a la última @alpha
omnicoder doctor           # chequeo de salud
omnicoder-routing list     # ver presets de per-phase routing
omnicoder-routing apply balanced   # Sonnet plan, Haiku build
```

## Auto-update

Al arrancar, el wrapper chequea el registry cada 24h. Si hay versión nueva, imprime en violeta:

```
→ omnicoder 5.0.0-alpha.12 available (current: 5.0.0-alpha.11)
  run:  omnicoder update
```

Para desactivar: `export OMNICODER_NO_UPDATE_CHECK=1`.

## ¿Y si algo falla?

Ver [`07-troubleshooting.md`](07-troubleshooting.md) o correr `omnicoder doctor`.
