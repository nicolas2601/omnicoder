# Slash Commands

OmniCoder registra 21 slash commands en `~/.omnicoder/commands/`. Cada uno es un archivo `.md` con frontmatter + workflow. Invócalos con `/nombre` desde la TUI.

## Tabla completa

| Comando | Descripción | Ejemplo |
|---------|-------------|---------|
| `/review` | Code review del diff actual con checklist P0-P3 (bugs, security, perf, smells) | `/review` tras editar varios archivos |
| `/ship` | Pre-flight completo: tests + lint + review + commit + push, todo en uno | `/ship` antes de subir a main |
| `/handoff` | Genera documento de continuidad para la próxima sesión (objetivo, progreso, próximos pasos) | `/handoff` al cerrar sesión larga |
| `/audit` | Auditoría completa: seguridad, performance, accesibilidad, dependencias, code quality | `/audit` en repo nuevo |
| `/refactor` | Refactor con snapshot + verificación de regresiones | `/refactor src/auth.js` |
| `/test-gen` | Genera tests para código sin cobertura. Detecta archivos sin tests y crea suites | `/test-gen src/utils/` |
| `/deps` | Análisis de dependencias: outdated, vulnerables, unused, peso del bundle | `/deps` antes de release |
| `/perf` | Detecta bottlenecks: N+1, O(n²), memory leaks. Sugiere optimizaciones | `/perf src/server.js` |
| `/compact` | Compresión inteligente de contexto con handoff automático | `/compact` cerca del token limit |
| `/doc-sync` | Sincroniza docs con código actual. Detecta desactualizados | `/doc-sync` tras refactor grande |
| `/plan` | Descompone tarea compleja en pasos ejecutables con estimación | `/plan implementar OAuth` |
| `/learn` | Analiza proyecto y guarda contexto en `./.omnicoder/memory/project.md` | `/learn` al entrar a repo nuevo |
| `/memory` | Gestor de memoria: list, show, forget, clean, stats | `/memory show patterns` |
| `/reflect` | Reflexión manual estilo Reflexion sobre sesión actual | `/reflect` tras bug fix difícil |
| `/patterns` | Gestión de patrones semánticos: list, add, forget, distill | `/patterns list` |
| `/skills-stats` | Dashboard de uso: skills usados, ignorados, zombies | `/skills-stats` semanal |
| `/meta` | Meta-análisis semanal: qué aprendió, qué mejoró, qué falla | `/meta` los viernes |
| `/verify-last` | Auditoría manual del output del último subagent | `/verify-last` tras Task sospechoso |
| `/turbo` | Toggle turbo mode: desactiva hooks pesados, respuestas ultra-concisas | `/turbo on` para velocidad |
| `/fast-model` | Configura modelo rápido como secundario para tareas simples | `/fast-model gemini-2.5-flash` |
| `/token-usage` | Estadísticas de tokens: por sesión y acumulado | `/token-usage` tras trabajo largo |

## Crear un command custom

### Ubicación

```
~/.omnicoder/commands/mi-command.md
```

### Formato

```markdown
---
name: mi-command
description: "Descripción corta de qué hace el command"
---

# Mi Command

## Workflow
1. Paso 1 con comando o tool
2. Paso 2 con criterio de éxito
3. Paso 3 con output esperado

## Ejemplos
- `/mi-command archivo.js`
- `/mi-command --flag`
```

### Buenas prácticas

- **Un command = un workflow claro**: no mezcles responsabilidades.
- **Usa tools explícitas**: indica qué `Bash`, `Edit`, `Read`, `Task` debe invocar.
- **Criterios de éxito medibles**: "tests pasan", "0 warnings en lint".
- **Combina con agentes**: invoca agentes específicos si la tarea es multi-dominio.

Ejemplo de command compuesto — mira `/home/nicolas/omnicoder/commands/ship.md` (pipeline completo con tests + review + commit + push).
