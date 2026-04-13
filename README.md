<p align="center">
  <img src="https://img.shields.io/badge/version-3.0.0-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/agents-168-green?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/skills-193-green?style=flat-square" alt="Skills">
  <img src="https://img.shields.io/badge/hooks-13-orange?style=flat-square" alt="Hooks">
  <img src="https://img.shields.io/badge/commands-17-purple?style=flat-square" alt="Commands">
  <img src="https://img.shields.io/badge/aprendizaje-adaptativo-red?style=flat-square" alt="Learning">
  <img src="https://img.shields.io/badge/memoria-dual-yellow?style=flat-square" alt="Memory">
  <img src="https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey?style=flat-square" alt="Platform">
</p>

<h1 align="center">Qwen Con Poderes v3</h1>

<p align="center">
  <strong>168 agentes + 193 skills + 13 hooks + 17 commands</strong> para <a href="https://github.com/QwenLM/qwen-code">Qwen Code CLI</a><br>
  Sistema cognitivo completo: memoria dual, aprendizaje adaptativo, router con enforcement, y destilación automática de patrones.
</p>

## Novedades v3.0 — Sistema Cognitivo Adaptativo

Basado en papers **ReasoningBank** (2025), **Reflexion** (NeurIPS 2023), **ExpeL** y **AgentBank** (NeurIPS 2024):

### Router v3 — Hybrid Scoring + Enforcement Adaptativo
- BM25-like scoring + bigramas + nombre + memoria feedback
- 3 niveles: **HARD** (score≥6, obligatorio), **SOFT** (3-5, sugerido), **HINT** (<3)
- Feedback loop: skill ignorado 3+ veces → router lo eleva a HARD automáticamente

### Memoria Dual (Episodic + Semantic)
- **Episodic**: `trajectories.md`, `learned.md`, `causal-edges.md`, `ignored-skills.md`
- **Semantic**: `patterns.md` (auto-destilado), `feedback.md`, `reflections.md`, `skill-stats.json`

### 5 Hooks de Aprendizaje
- `error-learner.sh` — Fallas con dedup md5
- `success-learner.sh` — **NUEVO** captura `tests-pass`, `build-ok`, `commit`
- `skill-usage-tracker.sh` — **NUEVO** detecta si ignoraste sugerencia del router
- `causal-learner.sh` — **NUEVO** aprende "si X falla → probar Y"
- `reflection.sh` — **NUEVO** auto-reflexión al cerrar sesión + destila cada 5

### 4 Nuevos Slash Commands
- `/reflect` — Reflexión manual estilo Reflexion
- `/patterns` — Gestión de patrones semánticos
- `/skills-stats` — Dashboard de uso (usados/ignorados/zombies)
- `/meta` — Meta-análisis semanal del aprendizaje

### Fix Timeout
- Config `contentGenerator.timeout: 180000` (3 min) evita el error "Streaming request timeout after 45s"

<p align="center">
  <a href="#instalacion">Instalacion</a> &bull;
  <a href="#arquitectura">Arquitectura</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#agentes">Agentes</a> &bull;
  <a href="#skills">Skills</a> &bull;
  <a href="#hooks">Hooks</a> &bull;
  <a href="#commands">Commands</a> &bull;
  <a href="#comparativa">Comparativa</a>
</p>

---

## Novedades v2.1 (Memoria + Razonamiento)

- **Skill Router v2**: scoring semantico por keywords contra las 193 descriptions de skills + 168 agentes (indice cacheado en `~/.qwen/.cache/`). Antes era regex con 12 patterns; ahora descubre skills nuevas sin tocar codigo.
- **Memoria persistente** (`~/.qwen/memory/`): MEMORY.md, feedback.md, learned.md, project_*.md. Se inyecta automaticamente al inicio de cada sesion via `memory-loader.sh`.
- **Error Learner**: hook `error-learner.sh` detecta fallos en PostToolUse (exit != 0, stderr con error) y los registra en `learned.md` con deduplicacion por hash. Evita repetir los mismos errores.
- **`/learn`**: comando que analiza el proyecto actual (package.json, README, git log) y escribe `./.qwen/memory/project.md` con stack, comandos, convenciones y archivos criticos.
- **`/memory`**: gestor de memoria (list, show, forget, clean, stats, export, import).

## Por que v2?

La v1 era un paquete de agentes y skills. La v2 es un **sistema completo de optimizacion** inspirado en las mejores practicas del ecosistema de agentes AI:

| Mejora | v1 | v2 | Impacto |
|--------|----|----|---------|
| Agentes | 168 | 168 | Misma cobertura |
| Skills | 193 | 193 | Misma cobertura |
| Hooks inteligentes | 0 | 7 | Seguridad + auto-routing |
| Slash commands | 0 | 11 | Workflows profesionales |
| Token optimization | No | Si | ~30-40% menos tokens |
| Security hooks | No | Si | Bloqueo de secrets y comandos peligrosos |
| Auto-routing de skills | No | Si | Sugiere skills automaticamente |
| Handoff entre sesiones | No | Si | Continuidad sin perder contexto |
| Doctor/diagnostico | No | Si | Auto-verificacion |
| settings.json con hooks | No | Si | Zero-config |

---

## Arquitectura

```
                    +------------------+
                    |    Tu Prompt     |
                    +--------+---------+
                             |
                    +--------v---------+
                    |   Skill Router   |  <-- Hook: auto-detecta intent
                    |   (UserPrompt)   |      y sugiere skill/agente
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
     +--------v---+  +------v------+  +----v--------+
     |  Nivel 1   |  |  Nivel 2    |  |  Nivel 3    |
     |  Simple    |  |  Medio      |  |  Complejo   |
     | Edit tool  |  | 1 SubAgent  |  | Multi-Agent |
     | directo    |  | enfocado    |  | coordinado  |
     +------------+  +-------------+  +-------------+
              |              |              |
     +--------v--------------v--------------v--------+
     |              Security Layer                     |
     |  Pre-Edit Guard | Security Guard | Secret Block |
     +-------------------------------------------------+
              |
     +--------v---------+
     |   Post-Tool Log   |  <-- Auditoria automatica
     +-------------------+
              |
     +--------v---------+
     |   Auto-Handoff    |  <-- Guarda progreso al terminar
     +-------------------+
```

### 3 Niveles de Complejidad

El sistema optimiza tokens automaticamente clasificando cada tarea:

| Nivel | Complejidad | Estrategia | Tokens | Ejemplo |
|-------|-------------|------------|--------|---------|
| **1** | Simple (<30%) | Edit directo | Minimo | Renombrar, fix typo |
| **2** | Media (30-70%) | 1 subagent | Moderado | Bug fix, feature |
| **3** | Alta (>70%) | Multi-agent | Maximo | Arquitectura, migracion |

---

## Instalacion

### One-liner automatizado (copia y pega)

**Linux / macOS:**
```bash
git clone https://github.com/nicolas2601/qwen-con-poderes-.git && cd qwen-con-poderes- && chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh
```

**Windows (RECOMENDADO: Git Bash):**

> **IMPORTANTE:** En Windows los hooks del sistema requieren `bash`. PowerShell y CMD **no funcionan** con los hooks activados (timeout al cargar settings.json). Usa **Git Bash**, que viene con [Git for Windows](https://git-scm.com/download/win).

```bash
# Abre "Git Bash" (NO PowerShell, NO CMD) y ejecuta:
git clone https://github.com/nicolas2601/qwen-con-poderes-.git && cd qwen-con-poderes- && chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh
```

**Windows (CMD) — solo si ya tienes bash/WSL en PATH:**
```cmd
git clone https://github.com/nicolas2601/qwen-con-poderes-.git && cd qwen-con-poderes- && scripts\install-windows.bat
```

**Windows (PowerShell) — solo si ya tienes bash/WSL en PATH:**
```powershell
git clone https://github.com/nicolas2601/qwen-con-poderes-.git; cd qwen-con-poderes-; .\scripts\install-windows.ps1
```

> Si instalaste con `.bat` o `.ps1` y ves `Request timed out waiting for hook-execution-response`, significa que falta `bash`. Desinstala (ver seccion [Desinstalar](#desinstalar)) y reinstala desde Git Bash.

Eso es todo. El instalador hace todo automaticamente:
1. Verifica Node.js v20+, npm, git, jq
2. Instala Qwen Code CLI si no esta
3. Copia 168 agentes a `~/.qwen/agents/`
4. Copia 193 skills a `~/.qwen/skills/`
5. Copia 7 hooks a `~/.qwen/hooks/`
6. Copia 13 commands a `~/.qwen/commands/`
7. Configura QWEN.md + settings.json con hooks
8. Crea directorio de logs

### Requisitos previos

| Requisito | Linux | Windows | macOS |
|-----------|-------|---------|-------|
| Node.js v20+ | `sudo pacman -S nodejs npm` / `sudo apt install nodejs` | `winget install OpenJS.NodeJS.LTS` | `brew install node` |
| Git | `sudo pacman -S git` / `sudo apt install git` | `winget install Git.Git` | `brew install git` |
| jq (para hooks) | `sudo pacman -S jq` / `sudo apt install jq` | Opcional | `brew install jq` |

### Opciones avanzadas (Linux/macOS)

```bash
./scripts/install-linux.sh --doctor     # Diagnostico (verifica que todo esta OK)
./scripts/install-linux.sh --force      # Sobreescribir todo
./scripts/install-linux.sh --skip-cli   # No instalar Qwen CLI
./scripts/install-linux.sh --help       # Ver todas las opciones
```

### Activar turbo mode (opcional, para maxima velocidad)

```bash
# Linux/macOS - despues de instalar:
chmod +x scripts/turbo-mode.sh && ./scripts/turbo-mode.sh on
```

### Verificar instalacion

```bash
./scripts/install-linux.sh --doctor
```

---

## Que se instala

```
~/.qwen/
├── agents/          168 archivos .md de subagentes
├── skills/          193 carpetas con SKILL.md
├── hooks/           7 hooks de automatizacion
│   ├── security-guard.sh      Bloquea comandos peligrosos
│   ├── pre-edit-guard.sh      Protege archivos sensibles
│   ├── post-tool-logger.sh    Logging de operaciones
│   ├── skill-router.sh        Auto-routing de skills
│   ├── session-init.sh        Carga contexto anterior
│   ├── auto-handoff.sh        Guarda progreso al salir
│   └── notify-desktop.sh      Notificaciones nativas
├── commands/        11 slash commands profesionales
│   ├── review.md              Code review P0-P3
│   ├── ship.md                Test+lint+commit+push
│   ├── handoff.md             Continuidad entre sesiones
│   ├── audit.md               Auditoria multi-dimension
│   ├── refactor.md            Refactor con verificacion
│   ├── test-gen.md            Generacion automatica de tests
│   ├── deps.md                Analisis de dependencias
│   ├── perf.md                Analisis de performance
│   ├── compact.md             Compresion inteligente
│   ├── doc-sync.md            Sincronizar documentacion
│   └── plan.md                Planificacion estructurada
├── QWEN.md          Instrucciones globales optimizadas
├── settings.json    Config con hooks pre-configurados
└── logs/            Directorio de auditoria
```

---

## Features

### Hooks Inteligentes

Los hooks se ejecutan automaticamente en puntos clave del ciclo de Qwen Code:

| Hook | Evento | Funcion |
|------|--------|---------|
| `security-guard` | PreToolUse (Bash) | Bloquea `rm -rf /`, fork bombs, `curl\|sh` y otros comandos peligrosos |
| `pre-edit-guard` | PreToolUse (Edit/Write) | Impide edicion de `.env`, `credentials.json`, keys SSH. Detecta API keys en contenido |
| `post-tool-logger` | PostToolUse | Registra cada operacion en `~/.qwen/logs/` con rotacion automatica |
| `skill-router` | UserPromptSubmit | Analiza tu prompt y sugiere el skill/agente mas relevante automaticamente |
| `session-init` | SessionStart | Detecta handoff previo, stack del proyecto, y branch actual |
| `auto-handoff` | Stop | Si la sesion fue productiva (5+ operaciones), sugiere crear handoff |
| `notify-desktop` | Notification | Envia notificaciones nativas (Linux notify-send / macOS osascript) |

### Slash Commands

| Comando | Descripcion |
|---------|-------------|
| `/review` | Code review estructurado con prioridades P0-P3 |
| `/ship` | Pipeline completo: tests -> lint -> review -> commit -> push |
| `/handoff` | Genera documento de continuidad para la proxima sesion |
| `/audit` | Auditoria: seguridad, performance, calidad, deps, testing |
| `/refactor` | Refactor seguro con snapshot + verificacion de regresiones |
| `/test-gen` | Genera tests para archivos sin cobertura |
| `/deps` | Analiza dependencias: vulnerables, outdated, unused |
| `/perf` | Detecta bottlenecks: N+1, O(n^2), memory leaks |
| `/compact` | Comprime contexto con handoff automatico |
| `/doc-sync` | Sincroniza documentacion con el codigo actual |
| `/plan` | Descompone tareas complejas en pasos ejecutables |

### Optimizacion de Tokens

Tecnicas integradas en el `QWEN.md`:

1. **Routing por complejidad** - No lanza subagents para tareas simples
2. **Lectura parcial** - Usa offset+limit en archivos grandes
3. **No repeticion** - Evita re-leer contenido ya en contexto
4. **Compresion proactiva** - `/compact` antes de llegar al limite
5. **Handoff documents** - Preserva contexto entre sesiones sin tokens
6. **Respuestas concisas** - Codigo > explicacion por defecto
7. **Batch operations** - Agrupa lecturas y escrituras en un mensaje

---

## Agentes (168)

### Por Categoria

| Categoria | Cantidad | Destacados |
|-----------|----------|------------|
| Engineering | 27 | `backend-architect`, `frontend-developer`, `software-architect`, `devops-automator` |
| Marketing | 29 | `seo-specialist`, `content-creator`, `growth-hacker`, `tiktok-strategist` |
| Specialized | 30 | `blockchain-security-auditor`, `mcp-builder`, `salesforce-architect` |
| Game Dev | 20 | `unity-architect`, `unreal-systems-engineer`, `godot-gameplay-scripter` |
| Design | 8 | `ui-designer`, `ux-architect`, `ux-researcher`, `brand-guardian` |
| Testing | 8 | `api-tester`, `accessibility-auditor`, `performance-benchmarker` |
| Sales | 8 | `sales-engineer`, `deal-strategist`, `outbound-strategist` |
| Paid Media | 7 | `ppc-strategist`, `programmatic-buyer`, `tracking-specialist` |
| Support | 6 | `analytics-reporter`, `finance-tracker`, `legal-compliance-checker` |
| Spatial Computing | 6 | `visionos-spatial-engineer`, `xr-immersive-developer` |
| Project Mgmt | 6 | `project-manager-senior`, `jira-workflow-steward` |
| Academic | 5 | `historian`, `psychologist`, `anthropologist` |
| Product | 5 | `product-manager`, `sprint-prioritizer`, `trend-researcher` |

### Uso

```bash
# Dentro de Qwen Code:
/agents manage                    # Ver todos los agentes
/agents create                    # Crear uno nuevo

# Usar en conversacion:
> Usa engineering-backend-architect para disenar mi API REST
> Necesito que marketing-seo-specialist audite mi sitio
```

---

## Skills (193)

193 skills organizadas en 15+ categorias, incluyendo **25 skills profesionales extra**:

| Skill | Funcion |
|-------|---------|
| `code-review` | Review con checklist P0-P3 |
| `comprehensive-review` | Review multi-subagent en paralelo |
| `audit-website` | Auditoria web: SEO, seguridad, performance |
| `maestro` | Gestion de repos complejos |
| `ui-ux-pro-max` | Diseno UI/UX: 50 estilos, 21 paletas |
| `playwright` | Automatizacion de browser |
| `gemini` | Code review con contexto grande |
| `vercel-react-best-practices` | Optimizacion React/Next.js |
| `react-native-best-practices` | Optimizacion React Native |
| `nano-banana-pro` | Generacion de imagenes |

```bash
# Invocar skill:
/skills code-review
/skills audit-website

# O simplemente describe tu tarea — Qwen selecciona automaticamente
```

---

## Comparativa

### Qwen Code Solo vs Qwen Con Poderes v2

| Feature | Qwen Code Base | Con Poderes v1 | Con Poderes v2 |
|---------|---------------|----------------|----------------|
| Agentes especializados | 0 | 168 | 168 |
| Skills profesionales | 0 | 193 | 193 |
| Security hooks | 0 | 0 | 7 |
| Slash commands pro | 0 | 0 | 11 |
| Token optimization | Basico | Basico | Avanzado (3 niveles) |
| Auto-routing de skills | No | No | Si |
| Handoff entre sesiones | No | No | Si |
| Auditoria de operaciones | No | No | Si |
| Doctor/diagnostico | No | No | Si |
| Notificaciones desktop | No | No | Si |
| settings.json pre-config | No | No | Si |

### vs Alternativas de pago

| Feature | Alternativas de pago | Qwen Con Poderes v2 |
|---------|---------------------|---------------------|
| Costo del CLI | $100-200/mes | **Gratis** (1000 req/dia) |
| Agentes | 100+ | **168** |
| Skills | 130+ | **193** |
| Security hooks | Si | Si |
| Auto-routing | Q-Learning | Pattern matching |
| Slash commands | Via MCP | **13 nativos** |
| Token optimization | 3-tier + WASM | **3 niveles + turbo mode** |
| Handoff documents | No nativo | **Si** |
| Multi-provider | Si | Si (OpenAI, Anthropic, Gemini, Ollama) |
| Open source | Si | **Si** |

---

## Crear tus propios componentes

### Agente custom

```markdown
---
name: mi-agente
description: "[categoria] Descripcion de tu agente"
color: blue
---

# Mi Agente

Eres un experto en [dominio]...

## Instrucciones
1. Siempre haz X
2. Nunca hagas Y
```

Guardar en `~/.qwen/agents/mi-agente.md`

### Skill custom

```bash
mkdir -p ~/.qwen/skills/mi-skill
```

```markdown
---
name: mi-skill
description: "Mi skill para [tarea]"
---

# Mi Skill

## Instrucciones
...
```

### Command custom

```markdown
---
name: mi-command
description: "Mi slash command para [workflow]"
---

# Mi Command

## Workflow
1. Paso 1
2. Paso 2
```

Guardar en `~/.qwen/commands/mi-command.md`

### Hook custom

Crear script en `~/.qwen/hooks/mi-hook.sh` y registrar en `settings.json`.

---

## Velocidad - Turbo Mode

Qwen Code con OAuth puede ser lento en tareas grandes. Aqui hay varias formas de acelerarlo:

### Turbo Mode (un comando)

```bash
# Activar turbo - desactiva hooks pesados, solo mantiene security-guard
./scripts/turbo-mode.sh on

# Restaurar modo normal
./scripts/turbo-mode.sh off

# Ver modo actual
./scripts/turbo-mode.sh status
```

Turbo mode hace:
- Solo mantiene `security-guard` y `notify-desktop` (los demas hooks se desactivan)
- `approval-mode: yolo` (sin pausas para pedir permiso)
- `temperature: 0.2` (respuestas mas directas y cortas)
- Token caching habilitado

### Modelo local con Ollama (respuestas en 1-5 segundos)

```bash
# Instalar Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Descargar modelo rapido para coding
ollama pull qwen2.5-coder:7b

# Dentro de Qwen Code, cambiar modelo:
/model
# Seleccionar el modelo local
```

### Headless mode (sin UI = sin lag de terminal)

```bash
# Ejecutar prompt sin interfaz interactiva
qwen -p "Crea un server Express basico en src/server.js" --yolo

# Pipe de archivos
cat src/auth.js | qwen -p "Review de seguridad" > review.txt
```

### Token caching (API Key > OAuth)

OAuth no soporta cache de tokens. Con API key puedes lograr ~90% cache hit:
```bash
# Dentro de Qwen Code:
/auth
# Seleccionar: Alibaba Cloud Coding Plan
# Obtener key: https://bailian.console.aliyun.com/
```

### Tips de prompts rapidos

```
Malo:  "Por favor, podrias crear un archivo que tenga un servidor..."
Bueno: "Crea src/server.js: Express, puerto 3000, CORS, sirve public/"

Malo:  "Crea 7 fases con 20 archivos, review, audit y handoff"
Bueno: "Crea el backend: server.js, routes/auth.js, routes/tasks.js, db.js"
       (luego en otro mensaje: "Ahora el frontend: index.html con Tailwind")
```

### Ver todos los tips

```bash
./scripts/speed-tips.sh
```

### Tabla de velocidad por configuracion

| Config | Velocidad | Costo |
|--------|-----------|-------|
| OAuth + hooks full | Lenta | Gratis |
| OAuth + turbo mode | Media | Gratis |
| API Key + turbo | Rapida | ~$0.01/req |
| Ollama local + turbo | Ultra rapida | Gratis |
| Headless + Ollama | Maxima | Gratis |

### Bug conocido: Scroll

En algunas terminales (especialmente en Linux/Windows), el scroll hacia arriba no funciona bien dentro de Qwen Code. Workarounds:

- **Shift+PgUp/PgDn** en vez de scroll con mouse
- **tmux**: `Ctrl+B` luego `[` para entrar en modo scroll
- **Terminales recomendadas**: kitty, wezterm, alacritty (mejor soporte TUI)
- **Headless mode**: `qwen -p "prompt" > output.txt` para ver todo el output

---

## Actualizar

```bash
cd qwen-con-poderes-
git pull
./scripts/install-linux.sh --force
```

## Desinstalar

**Linux / macOS / Git Bash en Windows:**
```bash
./scripts/uninstall-linux.sh
```

**Windows (PowerShell):**
```powershell
.\scripts\uninstall-windows.ps1
# O sin confirmacion:
.\scripts\uninstall-windows.ps1 -Force
```

**Windows (CMD):**
```cmd
scripts\uninstall-windows.bat
```

El desinstalador elimina agentes, skills, hooks, commands, logs y limpia la seccion `hooks` del `settings.json` (causa comun del error `Request timed out waiting for hook-execution-response` en Windows sin bash). NO toca Qwen Code CLI ni tu `settings.json` completo.

### Reinstalacion limpia desde Git Bash (fix del timeout en Windows)

Si instalaste con `.bat` o `.ps1` y tienes timeouts de hooks, sigue estos pasos:

```bash
# 1. Desde PowerShell/CMD, desinstala:
.\scripts\uninstall-windows.ps1 -Force

# 2. Instala Git for Windows si no lo tienes:
#    https://git-scm.com/download/win

# 3. Abre "Git Bash" y reinstala con el script de Linux:
git clone https://github.com/nicolas2601/qwen-con-poderes-.git
cd qwen-con-poderes-
chmod +x scripts/install-linux.sh
./scripts/install-linux.sh
```

---

## FAQ

**Necesito algun servicio de pago?**
No. Funciona 100% con Qwen Code CLI y OAuth gratis (1000 req/dia).

**Es gratis?**
Si. Qwen Code + OAuth = gratis. Los agentes, skills, hooks y commands son archivos locales.

**Puedo usar otros modelos?**
Si. Qwen Code soporta APIs compatibles con OpenAI, Anthropic, Gemini y mas.

**Los hooks ralentizan a Qwen?**
No. Los hooks son scripts bash livianos (<50ms de ejecucion).

**Necesito jq?**
Recomendado para los hooks. Sin jq, los hooks no funcionaran pero el resto si.

---

## Creditos

- [Qwen Code](https://github.com/QwenLM/qwen-code) - CLI base de Alibaba/Qwen
- [Ruflo](https://github.com/ruvnet/ruflo) - Inspiracion para hooks y routing
- [Awesome Qwen/AI Code](https://github.com/hesreallyhim/awesome-claude-code) - Inspiracion para commands y workflows
- [Context Engineering Kit](https://github.com/NeoLabHQ/context-engineering-kit) - Tecnicas de token optimization

Creado por [@nicolas2601](https://github.com/nicolas2601)

## Licencia

MIT
