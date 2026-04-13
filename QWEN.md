# Qwen Code - Instrucciones Globales (Qwen Con Poderes v2)

## Idioma
Siempre responde en Espanol.

## Modelo de Eficiencia (3 Niveles)

Antes de ejecutar cualquier tarea, evalua su complejidad:

| Nivel | Complejidad | Estrategia | Ejemplo |
|-------|-------------|------------|---------|
| 1 | Simple (<30%) | Edicion directa, sin subagent | Renombrar variable, fix typo, add import |
| 2 | Media (30-70%) | 1 subagent enfocado | Bug fix, feature pequena, refactor local |
| 3 | Alta (>70%) | Multi-subagent coordinado | Arquitectura, migracion, feature compleja |

Reglas:
- Nivel 1: Usa Edit tool directamente. NO lances subagents para cambios triviales
- Nivel 2: Lanza UN subagent con instrucciones precisas y contexto minimo
- Nivel 3: Maximo 3-5 subagents en paralelo con roles especificos

## Optimizacion de Tokens

### Reglas de Contexto Minimo
- NO leas archivos completos si solo necesitas una seccion. Usa offset+limit
- NO repitas contenido que ya esta en el contexto de la conversacion
- Usa /compress proactivamente cuando el contexto supere el 60%
- Respuestas concisas: codigo > explicacion. Solo explica si el usuario pregunta

### Handoff Documents
Cuando el contexto se acerque al limite o antes de /compress:
1. Crea un archivo `.qwen/handoff-{timestamp}.md` con:
   - Objetivo actual
   - Lo que funciono y lo que no
   - Proximos pasos concretos
   - Archivos relevantes con line numbers
2. En la nueva sesion, lee el handoff para retomar sin perder progreso

### Cache Hints
- Reutiliza herramientas con los mismos parametros cuando sea posible (token caching)
- Agrupa operaciones de lectura en un solo mensaje
- Agrupa operaciones de escritura en un solo mensaje

## Skills y Agentes Disponibles

### 193 Skills Instaladas (`~/.qwen/skills/`)
Invoca con `/skills <nombre>` o deja que se active automaticamente.

### 168 SubAgentes Instalados (`~/.qwen/agents/`)
Gestiona con `/agents manage` o `/agents create`.

### Catalogo Rapido por Dominio

**Desarrollo**: `engineering-backend-architect`, `engineering-frontend-developer`, `engineering-software-architect`, `engineering-code-reviewer`, `engineering-devops-automator`, `engineering-database-optimizer`, `engineering-security-engineer`, `engineering-mobile-app-builder`

**Diseno**: `design-ui-designer`, `design-ux-architect`, `design-ux-researcher`, `design-brand-guardian`

**Testing**: `testing-api-tester`, `testing-accessibility-auditor`, `testing-performance-benchmarker`, `testing-workflow-optimizer`

**Marketing**: `marketing-seo-specialist`, `marketing-content-creator`, `marketing-growth-hacker`, `marketing-tiktok-strategist`, `marketing-linkedin-content-creator`

**Producto**: `product-manager`, `product-sprint-prioritizer`, `product-feedback-synthesizer`

**Ventas**: `sales-engineer`, `sales-deal-strategist`, `sales-outbound-strategist`

**Game Dev**: `unity-architect`, `unreal-systems-engineer`, `godot-gameplay-scripter`, `game-designer`

**Skills Extra**: `code-review`, `comprehensive-review`, `audit-website`, `maestro`, `ui-ux-pro-max`, `playwright`, `gemini`, `nano-banana-pro`, `vercel-react-best-practices`, `react-native-best-practices`

## Reglas de Comportamiento

### Lo que SIEMPRE debes hacer
- Lee un archivo ANTES de editarlo
- Ejecuta tests despues de cambios en codigo
- Valida inputs en boundaries del sistema
- Usa las skills instaladas antes de dar respuestas genericas
- Combina multiples agentes para tareas multi-dominio

### Lo que NUNCA debes hacer
- Crear archivos innecesarios (prefiere editar existentes)
- Hardcodear secrets, API keys o credenciales
- Commitear .env o archivos con secrets
- Lanzar subagents para tareas de Nivel 1
- Repetir informacion que ya esta en contexto

## Sistema Cognitivo v3 — Aprendizaje Adaptativo

Qwen Con Poderes v3 implementa un sistema cognitivo completo inspirado en
**ReasoningBank** (2025), **Reflexion** (Shinn et al. 2023), **ExpeL**, y
**AgentBank** (NeurIPS 2024). No solo tiene memoria: aprende, reflexiona,
destila patrones y ajusta comportamiento adaptativamente.

### Arquitectura de Memoria (Dual: Episodic + Semantic)

**Memoria Episódica** (casos específicos):
- `~/.qwen/memory/trajectories.md` — Secuencias de tools exitosas (success-learner.sh)
- `~/.qwen/memory/learned.md` — Errores con contexto (error-learner.sh)
- `~/.qwen/memory/ignored-skills.md` — Skills sugeridos que no usaste
- `~/.qwen/memory/causal-edges.md` — Pares "si X falla → probar Y" (causal-learner.sh)

**Memoria Semántica** (reglas generalizables):
- `~/.qwen/memory/patterns.md` — Reglas destiladas (auto-promovidas cada 5 reflexiones)
- `~/.qwen/memory/feedback.md` — Feedback explícito del usuario
- `~/.qwen/memory/reflections.md` — Auto-reflexiones de sesión
- `~/.qwen/memory/skill-stats.json` — Contadores usado/ignorado por skill
- `~/.qwen/memory/MEMORY.md` — Índice maestro

**Regla dura:** si la memoria dice algo, ASUME. No preguntes lo ya sabido.

### Router v3 — Hybrid Scoring con Enforcement Adaptativo

`skill-router.sh` v3 usa scoring BM25-like + bigramas + memoria feedback:

```
Score base = Σ(term_freq_en_desc) + 3×(token_en_nombre) + 2×(bigrama_match)
Ajustes:
  + 1 si skill aparece en patterns.md (éxito previo)
  + 2 si skill fue ignorado 3+ veces (forzar uso)
  - 2 si skill aparece en learned.md con errores
```

**Niveles de Enforcement:**

| Score | Nivel | Comportamiento |
|-------|-------|----------------|
| ≥ 6 | **HARD** | `[OBLIGATORIO]` Usa el skill. No improvises. |
| 3-5 | **SOFT** | `[SUGERIDO]` Considera el skill antes de responder. |
| < 3 | **HINT** | Si la tarea es especializada, invoca `/skills find-skills`. |

**Loop de feedback:**
1. Router sugiere skill X con score 4.
2. Ignoras X 3 veces → `skill-usage-tracker.sh` lo registra.
3. Próxima vez, router re-scoree X con +2 → llega a 6 → HARD.
4. Ahora DEBES usar X.

### Aprendizaje Continuo — 5 Hooks PostToolUse

1. **error-learner.sh** — Registra fallas en `learned.md` con deduplicación md5.
2. **success-learner.sh** — Captura `tests-pass`, `build-ok`, `lint-clean`, `commit` → trajectories.md.
3. **skill-usage-tracker.sh** — Detecta si ignoraste sugerencia del router, actualiza stats.
4. **causal-learner.sh** — Buffer de 2 comandos. Si prev falló y curr éxito con mismo tema → causal edge.
5. **post-tool-logger.sh** — Log general.

### Reflexión y Destilación (Stop hook + cron)

**reflection.sh** (en cada Stop):
- Cuenta errores/éxitos/ignorados del día.
- Genera "lección" automática basada en heurísticas.
- Cada 5 reflexiones → auto-destila a `patterns.md`.

**distill-patterns.sh** (manual o cron weekly):
- Trayectorias con signal repetido 3+ veces → patrón confiable.
- Errores repetidos 2+ veces → "evitar".
- Skills ignorados 3+ veces → "forzar".

### Reglas de Uso de Skills (NO NEGOCIABLE)

1. **Si ves `[OBLIGATORIO]` en el contexto** → invoca ese skill SIEMPRE antes de responder.
2. **Si ves `[SUGERIDO]`** → usa el skill salvo que tengas razón fuerte contraria.
3. **Si ves `[HINT]`** → invoca `/skills find-skills` antes de improvisar.
4. **Nunca** resuelvas a mano algo que tiene skill dedicado. Desperdicia tokens y reputación.
5. **Tareas multi-dominio** → combina 2-3 agentes en paralelo (Task tool).

## Slash Commands

| Comando | Descripción |
|---------|-------------|
| `/review` | Code review del diff con checklist P0-P3 |
| `/ship` | Pre-flight: tests + lint + review + commit + push |
| `/handoff` | Handoff document para continuidad entre sesiones |
| `/audit` | Auditoría completa: seguridad, perf, accesibilidad |
| `/refactor` | Refactor con verificación de regresiones |
| `/test-gen` | Genera tests para código sin cobertura |
| `/doc-sync` | Sincroniza docs con el código |
| `/perf` | Análisis de performance |
| `/deps` | Dependencias: outdated, vulnerables, unused |
| `/plan` | Planificación estructurada |
| `/compact` | Compresión + handoff automático |
| `/learn` | Analiza proyecto → `./.qwen/memory/project.md` |
| `/memory` | Gestión memoria: list/show/forget/clean/stats |
| `/reflect` | **v3** Reflexión manual sobre sesión actual |
| `/patterns` | **v3** Gestión patrones semánticos (list/add/forget/distill) |
| `/skills-stats` | **v3** Dashboard: skills usados/ignorados/zombies |
| `/meta` | **v3** Meta-análisis semanal del aprendizaje |

## Hooks Activos (v3)

**PreToolUse**: security-guard + pre-edit-guard
**PostToolUse**: post-tool-logger + error-learner + **success-learner** + **skill-usage-tracker** + **causal-learner**
**UserPromptSubmit**: **skill-router v3** (hybrid scoring + enforcement)
**SessionStart**: session-init + memory-loader (carga patterns + feedback + learned)
**Stop**: auto-handoff + **reflection** (auto-destila cada 5 sesiones)
**Notification**: notify-desktop
