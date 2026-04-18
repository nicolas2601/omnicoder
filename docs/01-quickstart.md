# 01 · Quickstart

De cero a `omnicoder` corriendo en menos de 5 minutos.

---

## Requisitos

| | Linux / macOS | Windows 10/11 |
|---|---|---|
| Node.js 18 LTS+ | distro package / `nvm` | [nodejs.org](https://nodejs.org) |
| npm | incluido | incluido |
| git | distro package | [git-scm.com](https://git-scm.com/download/win) |
| PowerShell | — | 5.1+ (ya viene) o 7+ recomendado |
| `bun` (solo si vas a contribuir) | `curl -fsSL https://bun.sh/install \| bash` | `npm i -g bun` |
| Al menos una API key | `NVIDIA_API_KEY` **o** `MINIMAX_API_KEY` **o** `DASHSCOPE_API_KEY` **o** `ANTHROPIC_API_KEY` **o** `OPENAI_API_KEY` | idem |

---

## 1 · Clonar e instalar

```bash
# Linux / macOS
git clone https://github.com/nicolas2601/omnicoder-v5 ~/omnicoder-v5
cd ~/omnicoder-v5
bash scripts/install.sh --yes
```

```powershell
# Windows
git clone https://github.com/nicolas2601/omnicoder-v5 $env:USERPROFILE\omnicoder-v5
cd $env:USERPROFILE\omnicoder-v5
pwsh .\scripts\install-windows.ps1 -Yes
```

El installer es **idempotente** — correrlo dos veces no duplica nada y no
pisa tus archivos en `~/.omnicoder/` ni tu `opencode.jsonc`.

## 2 · Exportar una API key

```bash
# Linux / macOS (~/.bashrc, ~/.zshrc o ~/.config/fish/config.fish)
export NVIDIA_API_KEY="nvapi-..."
```

```powershell
# Windows — persistente a nivel usuario
[Environment]::SetEnvironmentVariable("NVIDIA_API_KEY", "nvapi-...", "User")
# abrir terminal nueva para que tome efecto
```

## 3 · Verificar

```bash
omnicoder --omnicoder-version
# omnicoder 5.0.0-alpha.1
# opencode  1.4.11

omnicoder doctor
# Status: healthy
```

## 4 · Lanzar el CLI

```bash
omnicoder
```

Se abre el TUI de Opencode con tus **193 skills**, **167 agents** y los
6 hooks del plugin cargados. Dentro del TUI, escribí tu tarea normal —
el skill-router BM25 va a inyectar skills relevantes y el security-guard
vigila los comandos bash.

## 5 · ¿Qué sigue?

- [`02-install.md`](02-install.md) — one-liner sin clonar, opciones
  avanzadas del installer.
- [`04-skills-agents.md`](04-skills-agents.md) — cómo reordenar skills,
  habilitar/deshabilitar agentes, crear los tuyos.
- [`05-hooks.md`](05-hooks.md) — qué hace cada hook y cómo escribir uno
  propio.
- [`control-del-cli.md`](control-del-cli.md) — modificar el fork
  directamente (renombrar comandos, nuevos subcomandos, branding).
