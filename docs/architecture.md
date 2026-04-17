# Arquitectura

## Flujo de una interacción

```
                      +-------------------+
                      |    User Prompt    |
                      +---------+---------+
                                |
                     UserPromptSubmit hook
                                |
                      +---------v---------+
                      |   skill-router    |  BM25 + bigramas + memoria
                      |   (enforcement)   |  -> [OBLIGATORIO] / [SUGERIDO] / [HINT]
                      +---------+---------+
                                |
                      +---------v---------+
                      |    LLM (provider) |  NVIDIA / Gemini / MiniMax / DeepSeek ...
                      +---------+---------+
                                |
                                |  tool_use (Bash, Edit, Write, Read, Task...)
                                |
                       PreToolUse hooks
            +-------------------+-------------------+
            | security-guard | pre-edit-guard |     |
            | subagent-inject (solo Task)           |
            +-------------------+-------------------+
                                |
                         tool execution
                                |
                      PostToolUse hooks
            +-------------------+-------------------+
            | post-tool-dispatcher (consolidado)    |
            |   -> logger / error-learner /         |
            |      success-learner /                |
            |      skill-usage-tracker /            |
            |      causal-learner / token-tracker   |
            | provider-failover                     |
            | subagent-verify + subagent-error-recover (Task)
            +-------------------+-------------------+
                                |
                      +---------v---------+
                      |   Memoria dual    |
                      |  Episodic + Sem.  |
                      +---------+---------+
                                |
                         Stop hook
                      +---------v---------+
                      |  reflection +     |
                      |  auto-handoff     |
                      +-------------------+
```

## Sistema cognitivo v4

Inspirado en **ReasoningBank** (2025), **Reflexion** (NeurIPS 2023), **ExpeL** y **AgentBank** (NeurIPS 2024). No es sólo memoria: aprende, reflexiona, destila patrones y ajusta comportamiento.

### Memoria dual

Ubicación: `~/.omnicoder/memory/`

**Episódica** (casos específicos):

| Archivo | Contenido |
|---------|-----------|
| `trajectories.md` | Secuencias de tools exitosas (éxitos, tests pasando, commits) |
| `learned.md` | Errores con contexto y md5 para dedup |
| `ignored-skills.md` | Skills sugeridos que no usaste |
| `causal-edges.md` | Pares "si X falla → probar Y" |

**Semántica** (reglas generalizables):

| Archivo | Contenido |
|---------|-----------|
| `patterns.md` | Reglas destiladas (auto-promoción cada 5 reflexiones) |
| `feedback.md` | Feedback explícito del usuario |
| `reflections.md` | Auto-reflexiones de sesión |
| `skill-stats.json` | Contadores usado/ignorado por skill |
| `MEMORY.md` | Índice maestro |

**Regla dura**: si la memoria dice algo, ASUME. No preguntes lo ya sabido.

### Router adaptativo

`skill-router.sh` v4.2 usa scoring híbrido:

```
Score base = Σ(term_freq_en_desc)
           + 3×(token_en_nombre)
           + 2×(bigrama_match)

Ajustes:
  + 1  si skill aparece en patterns.md (éxito previo)
  + 2  si skill fue ignorado 3+ veces (forzar uso)
  - 2  si skill aparece en learned.md con errores
```

**Enforcement adaptativo:**

| Score | Nivel | Comportamiento |
|-------|-------|----------------|
| ≥ 12 | `[OBLIGATORIO]` HARD | Usa el skill. No improvises |
| 7–11 | `[SUGERIDO]` SOFT | Considera antes de responder |
| < 7 | `[HINT]` | Especializada → invoca `/skills find-skills` |

**Loop de feedback**: si ignoras X tres veces, `skill-usage-tracker.sh` lo registra y el router le aplica +2 al score la próxima vez. Eventualmente sube a HARD y deja de ser opcional.

## 3 niveles de complejidad

El agente clasifica cada tarea antes de ejecutar para optimizar tokens:

| Nivel | Complejidad | Estrategia | Tokens | Ejemplo |
|-------|-------------|------------|--------|---------|
| **1** | <30% | Edit directo | Mínimo | Renombrar, fix typo, add import |
| **2** | 30–70% | 1 subagent enfocado | Moderado | Bug fix, feature pequeña |
| **3** | >70% | 3–5 subagents en paralelo | Máximo | Arquitectura, migración, feature compleja |

Reglas:

- Nivel 1: `Edit` directamente. NO lances subagents para cambios triviales.
- Nivel 2: UN subagent con instrucciones precisas y contexto mínimo.
- Nivel 3: Máximo 3–5 subagents en paralelo con roles específicos.

## Verificación de subagents

Los subagents tienden a reportar éxito sin hacer el trabajo real. OmniCoder lo impide con dos hooks:

- `subagent-inject.sh` (PreToolUse Task): inyecta el contrato de evidencia antes de ejecutar.
- `subagent-verify.sh` (PostToolUse Task): parsea el bloque `<verification>`, valida mtime de archivos, evidencia de tests, comandos loggeados. Si falla, emite `[VERIFICACION-FALLIDA]`.

### Contrato obligatorio

Todo subagent debe terminar con:

```xml
<verification>
files: [ruta/archivo1, ruta/archivo2]
commands: [npm test, git diff]
tests: true|false
summary: resumen breve
</verification>
```

Si ves `[VERIFICACION-FALLIDA]` tras un Task, NO reportes "listo" al usuario. Verifica manualmente con `Read` / `git diff --stat` o invoca `/verify-last`.

## Relación hooks ↔ memoria ↔ router

1. **SessionStart** → `memory-loader.sh` carga `patterns.md + feedback.md + learned.md` como contexto inicial.
2. **UserPromptSubmit** → `skill-router.sh` lee `skill-stats.json` para ajustar scoring adaptativo.
3. **PostToolUse** → `post-tool-dispatcher.sh` v4.3 escribe a `trajectories.md`, `learned.md`, `causal-edges.md`, `skill-stats.json` en background.
4. **Stop** → `reflection.sh` sintetiza la sesión; cada 5 reflexiones destila a `patterns.md`.

Esta retroalimentación cierra el loop: lo que aprende en una sesión cambia el comportamiento del router en la siguiente.

## Hooks activos (v4.3.1)

| Evento | Hook | Proposito |
|--------|------|-----------|
| UserPromptSubmit | `skill-router-lite.sh` | Default fast-path. 80% prompts: 0-15 bytes. Delega a full router solo si prompt >100 palabras o tech nueva |
| UserPromptSubmit | `skill-router.sh` (via lite) | Scoring BM25 + bigramas + memoria cuando se requiere |
| SessionStart | `session-init.sh` | Stack detection, cwd info |
| SessionStart | `memory-loader.sh` | Carga `patterns.md` + `feedback.md`. Episodic (learned/causal/trajectories) bajo demanda via `/memory` |
| SessionStart | `token-budget.sh` | Warning si promedio ultimas 10 sesiones supera 15k tokens |
| PreToolUse | `security-guard.sh`, `pre-edit-guard.sh`, `subagent-inject.sh` | Guardrails y contrato de verificacion |
| PostToolUse | `post-tool-dispatcher.sh` | Consolidado: logger + error/success/skill/causal learners + token-tracker |
| PostToolUse | `subagent-verify.sh` | Audita `<verification>` de subagents |
| Stop | `auto-handoff.sh`, `reflection.sh` | Handoff + destilacion cada 5 sesiones |

## Presupuesto de tokens (v4.3.1)

Reduccion sobre baseline v4.3:

| Fuente | Antes | Despues | Reduccion |
|--------|-------|---------|-----------|
| `OMNICODER.md` (system prompt) | 10.758 B | ~2.400 B | -78% |
| `memory-loader.sh` (SessionStart) | 2.500 B | 1.200 B | -52% |
| `skills-index.tsv` (indirecto) | 64 KB | ~20 KB | -69% |
| Router per-prompt (prompts simples) | ~100 B | 0-15 B | -85% |

**Fast-path router-lite** emite output en 3 casos:
- Prompt <20 palabras sin tech keyword -> `{}` (0 bytes).
- Tech detectada + prompt corto -> `[TECH:X]` (~15 bytes).
- Prompt >100 palabras o tech nueva -> delega a full router.
