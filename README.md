<p align="center">
  <img src="https://img.shields.io/badge/version-4.2.0-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/agents-168-green?style=flat-square" alt="Agents">
  <img src="https://img.shields.io/badge/skills-193-green?style=flat-square" alt="Skills">
  <img src="https://img.shields.io/badge/hooks-18-orange?style=flat-square" alt="Hooks">
  <img src="https://img.shields.io/badge/commands-21-purple?style=flat-square" alt="Commands">
  <img src="https://img.shields.io/badge/aprendizaje-adaptativo-red?style=flat-square" alt="Learning">
  <img src="https://img.shields.io/badge/memoria-dual-yellow?style=flat-square" alt="Memory">
  <img src="https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey?style=flat-square" alt="Platform">
</p>

<h1 align="center">⚡ OmniCoder v4.2</h1>
<p align="center"><em>Tu terminal, 168 expertos. Cero suscripciones.</em></p>

<p align="center">
  <strong>168 agentes + 193 skills + 18 hooks + 21 commands</strong> para <a href="https://github.com/QwenLM/qwen-code">Qwen Code CLI</a><br>
  Sistema cognitivo completo: memoria dual, aprendizaje adaptativo, router con enforcement, y destilacion automatica de patrones.<br>
  <strong>Model-agnostic</strong>: funciona con cualquier API compatible con OpenAI (NVIDIA, Gemini, MiniMax, DeepSeek, OpenRouter, Ollama).
</p>

## Novedades v4.2 — Branding, Bug Fixes, Windows Parity

- **Rebranding completo**: la TUI interna ahora muestra "OmniCoder" en vez de "Qwen Code" (patch automatico durante instalacion).
- **Fix critico: skill-usage-tracker**: el tracker de skills ignorados no funcionaba (filename mismatch `last-suggestions.json` vs `last-suggestion.json`). Corregido.
- **Fix: jq tostring bug**: el skill-stats.json se corrompia por un `| tostring` espurio. Corregido.
- **Contadores corregidos**: ahora todos los archivos reflejan los contadores reales (18 hooks, 21 commands).
- **Windows parity**: el instalador Windows (.bat/.ps1) ahora instala memoria persistente y construye el indice de skills (antes solo lo hacia Linux).
- **Thresholds documentados correctamente**: OMNICODER.md ahora refleja los thresholds reales del router (≥12 HARD, 7-11 SOFT).
- **Router v4.2**: header corregido (decia "Claude Code", ahora "OmniCoder").

## Novedades v4.0 — Model-Agnostic + Multi-Provider

OmniCoder v4 es completamente **model-agnostic**. Ya no dependes de un solo proveedor:

- **Multi-provider nativo**: NVIDIA NIM, Google Gemini, MiniMax, DeepSeek, OpenRouter, Ollama, y cualquier API compatible con OpenAI.
- **Switch de proveedor en caliente**: cambia entre proveedores sin reiniciar la sesion.
- **Sin suscripciones obligatorias**: usa modelos locales (Ollama), tiers gratuitos, o tu API key preferida.
- **`subagent-inject.sh`** ahora detecta prompts >4000 chars o con >6 backticks y
  advierte al orquestador ANTES de spawnear (evita errores preventivamente).
- **`subagent-error-recover.sh`** (PostToolUse Task) detecta 4 patrones
  de error 400 y emite `[SUBAGENT-400-DETECTADO]` con plan de recuperacion:
  acortar prompt, quitar code-fences, usar Edit directo, o secuencial en vez
  de paralelo con 3+ subagents.
- Contador de errores en `~/.omnicoder/logs/subagent-400-errors.log`. Tras 3+ errores
  sugiere `turbo-mode on` o modelo alternativo.
- El agente principal ya NO puede reportar "listo" tras un fallo silencioso.

## Sistema Cognitivo Adaptativo

Basado en papers **ReasoningBank** (2025), **Reflexion** (NeurIPS 2023), **ExpeL** y **AgentBank** (NeurIPS 2024):

### Router v4 — Hybrid Scoring + Enforcement Adaptativo
- BM25-like scoring + bigramas + nombre + memoria feedback
- 3 niveles: **HARD** (score>=6, obligatorio), **SOFT** (3-5, sugerido), **HINT** (<3)
- Feedback loop: skill ignorado 3+ veces -> router lo eleva a HARD automaticamente

### Memoria Dual (Episodic + Semantic)
- **Episodic**: `trajectories.md`, `learned.md`, `causal-edges.md`, `ignored-skills.md`
- **Semantic**: `patterns.md` (auto-destilado), `feedback.md`, `reflections.md`, `skill-stats.json`

### 5 Hooks de Aprendizaje
- `error-learner.sh` — Fallas con dedup md5
- `success-learner.sh` — Captura `tests-pass`, `build-ok`, `commit`
- `skill-usage-tracker.sh` — Detecta si ignoraste sugerencia del router
- `causal-learner.sh` — Aprende "si X falla -> probar Y"
- `reflection.sh` — Auto-reflexion al cerrar sesion + destila cada 5

### 4 Slash Commands Cognitivos
- `/reflect` — Reflexion manual estilo Reflexion
- `/patterns` — Gestion de patrones semanticos
- `/skills-stats` — Dashboard de uso (usados/ignorados/zombies)
- `/meta` — Meta-analisis semanal del aprendizaje

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
git clone https://github.com/nicolas2601/omnicoder.git && cd omnicoder && chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh
```

**Windows (RECOMENDADO: Git Bash):**

> **IMPORTANTE:** En Windows los hooks del sistema requieren `bash`. PowerShell y CMD **no funcionan** con los hooks activados (timeout al cargar settings.json). Usa **Git Bash**, que viene con [Git for Windows](https://git-scm.com/download/win).

```bash
# Abre "Git Bash" (NO PowerShell, NO CMD) y ejecuta:
git clone https://github.com/nicolas2601/omnicoder.git && cd omnicoder && chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh
```

**Windows (CMD) — solo si ya tienes bash/WSL en PATH:**
```cmd
git clone https://github.com/nicolas2601/omnicoder.git && cd omnicoder && scripts\install-windows.bat
```

**Windows (PowerShell) — solo si ya tienes bash/WSL en PATH:**
```powershell
git clone https://github.com/nicolas2601/omnicoder.git; cd omnicoder; .\scripts\install-windows.ps1
```

> Si instalaste con `.bat` o `.ps1` y ves `Request timed out waiting for hook-execution-response`, significa que falta `bash`. Desinstala (ver seccion [Desinstalar](#desinstalar)) y reinstala desde Git Bash.

Eso es todo. El instalador hace todo automaticamente:
1. Verifica Node.js v20+, npm, git, jq
2. Instala Qwen Code CLI si no esta (upstream: `@qwen-code/qwen-code`)
3. Copia 168 agentes a `~/.omnicoder/agents/`
4. Copia 193 skills a `~/.omnicoder/skills/`
5. Copia 16 hooks a `~/.omnicoder/hooks/`
6. Copia 20 commands a `~/.omnicoder/commands/`
7. Configura OMNICODER.md + settings.json con hooks
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
~/.omnicoder/
├── agents/          168 archivos .md de subagentes
├── skills/          193 carpetas con SKILL.md
├── hooks/           18 hooks de automatizacion
│   ├── security-guard.sh      Bloquea comandos peligrosos
│   ├── pre-edit-guard.sh      Protege archivos sensibles
│   ├── post-tool-logger.sh    Logging de operaciones
│   ├── skill-router.sh        Auto-routing de skills
│   ├── session-init.sh        Carga contexto anterior
│   ├── auto-handoff.sh        Guarda progreso al salir
│   ├── notify-desktop.sh      Notificaciones nativas
│   ├── error-learner.sh       Aprende de fallas
│   ├── success-learner.sh     Aprende de exitos
│   ├── skill-usage-tracker.sh Tracking de skills ignoradas
│   ├── causal-learner.sh      Aprendizaje causal
│   ├── reflection.sh          Auto-reflexion
│   ├── subagent-inject.sh     Validacion pre-spawn
│   ├── subagent-verify.sh     Verifica trabajo de subagents
│   ├── subagent-error-recover.sh  Recuperacion de errores 400
│   ├── memory-loader.sh       Carga memoria al inicio
│   ├── provider-failover.sh   Auto-failover de provider
│   └── token-tracker.sh       Tracking de consumo de tokens
├── commands/        21 slash commands profesionales
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
│   ├── plan.md                Planificacion estructurada
│   ├── reflect.md             Reflexion manual
│   ├── patterns.md            Gestion de patrones
│   ├── skills-stats.md        Dashboard de uso
│   ├── meta.md                Meta-analisis semanal
│   ├── learn.md               Aprende del proyecto actual
│   ├── memory.md              Gestor de memoria
│   ├── agents.md              Gestor de agentes
│   ├── provider.md            Cambio de proveedor
│   ├── turbo.md               Toggle turbo mode
│   └── verify-last.md         Auditoria del ultimo subagent
├── OMNICODER.md     Instrucciones globales optimizadas
├── settings.json    Config con hooks pre-configurados
└── logs/            Directorio de auditoria
```

---

## Features

### Hooks Inteligentes

Los hooks se ejecutan automaticamente en puntos clave del ciclo de OmniCoder:

| Hook | Evento | Funcion |
|------|--------|---------|
| `security-guard` | PreToolUse (Bash) | Bloquea `rm -rf /`, fork bombs, `curl\|sh` y otros comandos peligrosos |
| `pre-edit-guard` | PreToolUse (Edit/Write) | Impide edicion de `.env`, `credentials.json`, keys SSH. Detecta API keys en contenido |
| `subagent-inject` | PreToolUse (Task) | Inyecta contrato de evidencia + reglas anti-400 a subagents |
| `post-tool-logger` | PostToolUse | Registra cada operacion en `~/.omnicoder/logs/` con rotacion automatica |
| `error-learner` | PostToolUse | Registra fallas en `learned.md` con deduplicacion md5 |
| `success-learner` | PostToolUse | Captura trayectorias exitosas (tests, builds, commits) |
| `skill-usage-tracker` | PostToolUse | Detecta skills ignorados, cierra el feedback loop del router |
| `causal-learner` | PostToolUse | Aprende pares "si X falla → probar Y" |
| `token-tracker` | PostToolUse | Tracking de consumo estimado de tokens por sesion |
| `provider-failover` | PostToolUse | Detecta fallas de API (429, 503, timeout) y sugiere cambio de provider |
| `subagent-verify` | PostToolUse (Task) | Valida que subagents completaron trabajo real (mtime, tests, logs) |
| `subagent-error-recover` | PostToolUse (Task) | Detecta errores 400 del modelo coder y emite plan de recovery |
| `skill-router` | UserPromptSubmit | Analiza tu prompt y sugiere el skill/agente mas relevante (BM25 + bigramas) |
| `session-init` | SessionStart | Detecta handoff previo, stack del proyecto, y branch actual |
| `memory-loader` | SessionStart | Carga memoria dual (episodic + semantic) como contexto inicial |
| `auto-handoff` | Stop | Si la sesion fue productiva (5+ operaciones), sugiere crear handoff |
| `reflection` | Stop | Auto-reflexion: errores/exitos/ignorados. Destila a patterns.md cada 5 sesiones |
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
| `/reflect` | Reflexion manual estilo Reflexion |
| `/patterns` | Gestion de patrones semanticos |
| `/skills-stats` | Dashboard de uso de skills |
| `/meta` | Meta-analisis semanal del aprendizaje |
| `/learn` | Analiza proyecto y escribe contexto en memoria |
| `/memory` | Gestor de memoria (list, show, forget, stats) |
| `/agents` | Gestor de agentes (list, create, manage) |
| `/provider` | Cambiar proveedor de API en caliente |
| `/turbo` | Toggle turbo mode on/off |

### Optimizacion de Tokens

Tecnicas integradas en el `OMNICODER.md`:

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
# Dentro de OmniCoder:
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

# O simplemente describe tu tarea — OmniCoder selecciona automaticamente
```

---

## Comparativa

### CLI Base vs OmniCoder v4

| Feature | Qwen Code CLI | OmniCoder v4 |
|---------|---------------|--------------|
| Agentes especializados | 0 | 168 |
| Skills profesionales | 0 | 193 |
| Security hooks | 0 | 18 |
| Slash commands pro | 0 | 21 |
| Token optimization | Basico | Avanzado (3 niveles) |
| Auto-routing de skills | No | Si |
| Handoff entre sesiones | No | Si |
| Auditoria de operaciones | No | Si |
| Doctor/diagnostico | No | Si |
| Notificaciones desktop | No | Si |
| settings.json pre-config | No | Si |
| Multi-provider | Manual | Nativo (6+ proveedores) |
| Memoria dual | No | Si (Episodic + Semantic) |
| Aprendizaje adaptativo | No | Si (5 hooks cognitivos) |

### vs Alternativas de pago

| Feature | Alternativas de pago | OmniCoder v4 |
|---------|---------------------|--------------|
| Costo del CLI | $100-200/mes | **Gratis** (usa tu proveedor) |
| Agentes | 100+ | **168** |
| Skills | 130+ | **193** |
| Security hooks | Si | Si (18) |
| Auto-routing | Q-Learning | Pattern matching + BM25 |
| Slash commands | Via MCP | **21 nativos** |
| Token optimization | 3-tier + WASM | **3 niveles + turbo mode** |
| Handoff documents | No nativo | **Si** |
| Multi-provider | Si | **Si** (NVIDIA, Gemini, MiniMax, DeepSeek, OpenRouter, Ollama) |
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

Guardar en `~/.omnicoder/agents/mi-agente.md`

### Skill custom

```bash
mkdir -p ~/.omnicoder/skills/mi-skill
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

Guardar en `~/.omnicoder/commands/mi-command.md`

### Hook custom

Crear script en `~/.omnicoder/hooks/mi-hook.sh` y registrar en `settings.json`.

---

## Velocidad - Turbo Mode

OmniCoder con providers remotos puede ser lento en tareas grandes. Aqui hay varias formas de acelerarlo:

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

# Dentro de OmniCoder, cambiar modelo:
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

### Proveedores recomendados

| Proveedor | Modelos destacados | Tier gratuito | Notas |
|-----------|-------------------|---------------|-------|
| **NVIDIA NIM** | qwen2.5-coder, llama-3.1 | Si (1000 req/dia) | Baja latencia |
| **Google Gemini** | gemini-2.5-flash, gemini-2.5-pro | Si (limitado) | Contexto grande |
| **MiniMax** | MiniMax-M2.7 | $10/mes plan | Buena relacion costo/calidad |
| **DeepSeek** | deepseek-coder-v2 | Si (limitado) | Especializado en codigo |
| **OpenRouter** | Multiples modelos | Varia | Agregador multi-modelo |
| **Ollama** | qwen2.5-coder:7b, codellama | Gratis (local) | Sin internet, maxima privacidad |

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
| API remota + hooks full | Lenta | Varia |
| API remota + turbo mode | Media | Varia |
| API key dedicada + turbo | Rapida | ~$0.01/req |
| Ollama local + turbo | Ultra rapida | Gratis |
| Headless + Ollama | Maxima | Gratis |

### Bug conocido: Scroll

En algunas terminales (especialmente en Linux/Windows), el scroll hacia arriba no funciona bien dentro del CLI. Workarounds:

- **Shift+PgUp/PgDn** en vez de scroll con mouse
- **tmux**: `Ctrl+B` luego `[` para entrar en modo scroll
- **Terminales recomendadas**: kitty, wezterm, alacritty (mejor soporte TUI)
- **Headless mode**: `qwen -p "prompt" > output.txt` para ver todo el output

---

## Actualizar

```bash
cd omnicoder
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

El desinstalador elimina agentes, skills, hooks, commands, logs y limpia la seccion `hooks` del `settings.json` (causa comun del error `Request timed out waiting for hook-execution-response` en Windows sin bash). NO toca el CLI base ni tu `settings.json` completo.

### Reinstalacion limpia desde Git Bash (fix del timeout en Windows)

Si instalaste con `.bat` o `.ps1` y tienes timeouts de hooks, sigue estos pasos:

```bash
# 1. Desde PowerShell/CMD, desinstala:
.\scripts\uninstall-windows.ps1 -Force

# 2. Instala Git for Windows si no lo tienes:
#    https://git-scm.com/download/win

# 3. Abre "Git Bash" y reinstala con el script de Linux:
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder
chmod +x scripts/install-linux.sh
./scripts/install-linux.sh
```

---

## FAQ

**Necesito algun servicio de pago?**
No. OmniCoder funciona con cualquier API compatible con OpenAI. Hay multiples proveedores con tiers gratuitos (NVIDIA NIM, DeepSeek, Gemini) o puedes usar Ollama 100% local y gratis.

**Es gratis?**
Si. OmniCoder es open source. El CLI base (Qwen Code) es gratuito. Los agentes, skills, hooks y commands son archivos locales. Solo pagas si eliges un proveedor de API de pago.

**Puedo usar otros modelos?**
Si. OmniCoder es model-agnostic. Soporta NVIDIA NIM, Google Gemini, MiniMax, DeepSeek, OpenRouter, Ollama, y cualquier API compatible con OpenAI/Anthropic.

**Los hooks ralentizan al CLI?**
No. Los hooks son scripts bash livianos (<50ms de ejecucion). Usa turbo mode si quieres desactivar los no esenciales.

**Necesito jq?**
Recomendado para los hooks. Sin jq, los hooks no funcionaran pero el resto si.

**Que relacion tiene con Qwen Code?**
OmniCoder es un fork (bajo Apache 2.0) de [Qwen Code CLI](https://github.com/QwenLM/qwen-code). El comando `qwen` y el paquete `@qwen-code/qwen-code` son del proyecto upstream. OmniCoder agrega el sistema cognitivo completo (agentes, skills, hooks, commands, memoria) encima del CLI base.

---

## Creditos

- [Qwen Code](https://github.com/QwenLM/qwen-code) - CLI base (fork bajo Apache 2.0)
- [Ruflo](https://github.com/ruvnet/ruflo) - Inspiracion para hooks y routing
- [Awesome Qwen/AI Code](https://github.com/hesreallyhim/awesome-claude-code) - Inspiracion para commands y workflows
- [Context Engineering Kit](https://github.com/NeoLabHQ/context-engineering-kit) - Tecnicas de token optimization

Creado por [@nicolas2601](https://github.com/nicolas2601)

## Licencia

MIT

> **Nota:** El CLI base ([Qwen Code](https://github.com/QwenLM/qwen-code)) esta licenciado bajo Apache 2.0 por Alibaba/Qwen. OmniCoder (agentes, skills, hooks, commands, configuracion) esta bajo licencia MIT. Se mantiene la atribucion requerida por Apache 2.0 para el codigo upstream.
