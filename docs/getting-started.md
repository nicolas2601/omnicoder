# Getting Started

## Qué es OmniCoder

OmniCoder v4.3 es una extensión cognitiva para [Qwen Code CLI](https://github.com/QwenLM/qwen-code) que convierte tu terminal en un entorno con 168 agentes especializados, 193 skills, 19 hooks y 21 slash commands. Model-agnostic: funciona con NVIDIA NIM, Gemini, MiniMax, DeepSeek, OpenRouter y Ollama. Sin suscripciones obligatorias.

## Prerequisitos

| Requisito | Versión | Instalación |
|-----------|---------|-------------|
| Node.js | v20+ | `sudo pacman -S nodejs npm` / `brew install node` / `winget install OpenJS.NodeJS.LTS` |
| bash | 4.0+ | nativo en Linux/macOS, `Git for Windows` en Windows |
| git | cualquiera | `sudo pacman -S git` / `brew install git` |
| jq | cualquiera | `sudo pacman -S jq` / `brew install jq` (requerido por hooks) |

## Instalación

### One-liner (Linux / macOS / Git Bash en Windows)

```bash
git clone https://github.com/nicolas2601/omnicoder.git && cd omnicoder && chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh
```

### Instalación manual paso a paso

```bash
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder
chmod +x scripts/install-linux.sh
./scripts/install-linux.sh
```

El instalador:

1. Verifica Node.js v20+, npm, git y jq.
2. Instala Qwen Code CLI si no está (`@qwen-code/qwen-code`).
3. Copia 168 agentes a `~/.omnicoder/agents/`.
4. Copia 193 skills a `~/.omnicoder/skills/`.
5. Copia 19 hooks a `~/.omnicoder/hooks/`.
6. Copia 21 commands a `~/.omnicoder/commands/`.
7. Escribe `OMNICODER.md` + `settings.json` con hooks registrados.
8. Construye el índice BM25 del router.

### Opciones del instalador

```bash
./scripts/install-linux.sh --doctor    # Diagnóstico
./scripts/install-linux.sh --force     # Sobreescribe todo
./scripts/install-linux.sh --skip-cli  # No instala el CLI base
./scripts/install-linux.sh --help      # Todas las opciones
```

### Windows (CMD o PowerShell, sin bash)

Si no tienes Git Bash, usa el instalador nativo:

```cmd
scripts\install-windows.bat
```

```powershell
.\scripts\install-windows.ps1
```

> Si ves `Request timed out waiting for hook-execution-response`, instala [Git for Windows](https://git-scm.com/download/win) y reinstala desde Git Bash.

## Primera sesión

```bash
omnicoder
```

Se lanza la TUI. El sistema cognitivo ya está activo: cada prompt pasa por el router, los hooks aprenden de cada operación y la memoria persiste entre sesiones.

Prueba rápida:

```
> Usa engineering-backend-architect para diseñar una API REST de tareas
```

El router detectará el agente adecuado, lo invocará vía Task tool, y `subagent-verify.sh` validará que el trabajo se hizo.

## Configurar proveedor

```bash
./scripts/setup-provider.sh
```

Ver detalles en [providers.md](./providers.md).

## Turbo mode

Para máxima velocidad en tareas grandes:

```bash
./scripts/turbo-mode.sh on
```

Desactiva hooks pesados (mantiene sólo `security-guard`).

## Verificar instalación

```bash
./scripts/install-linux.sh --doctor
```

## Troubleshooting

Problemas comunes (timeouts de hooks, rate limits, scroll bug TUI) están documentados en [troubleshooting.md](./troubleshooting.md).
