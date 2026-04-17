# Agentes

OmniCoder instala 168 agentes especializados en `~/.omnicoder/agents/`. Cada uno es un archivo `.md` con frontmatter y system prompt: describe el rol, la metodología y las reglas de un experto de dominio.

## Cómo usar un agente

### Desde la TUI (conversación natural)

```
> Usa engineering-backend-architect para diseñar mi API REST
> Necesito que marketing-seo-specialist audite mi sitio
> Que design-ui-designer revise este componente
```

El router detecta el nombre y el modelo invoca el agente vía la herramienta Task. `subagent-inject.sh` inyecta el contrato de verificación antes del spawn.

### Con slash command

```
/agents manage      # Lista todos los agentes disponibles
/agents create      # Wizard para crear uno nuevo
```

### En paralelo (multi-dominio)

Para tareas que cruzan dominios, lanza 2–3 agentes en paralelo en un solo mensaje. El agente principal coordina los resultados.

## Catálogo por categoría

| Categoría | Conteo | Destacados |
|-----------|--------|------------|
| Engineering | 27 | `backend-architect`, `frontend-developer`, `software-architect`, `devops-automator`, `database-optimizer`, `security-engineer`, `mobile-app-builder`, `cms-developer` |
| Marketing | 29 | `seo-specialist`, `content-creator`, `growth-hacker`, `tiktok-strategist`, `linkedin-content-creator`, `xiaohongshu-specialist` |
| Specialized | 30 | `blockchain-security-auditor`, `mcp-builder`, `salesforce-architect`, `zk-steward`, `compliance-auditor` |
| Game Dev | 20 | `unity-architect`, `unreal-systems-engineer`, `godot-gameplay-scripter`, `game-designer`, `technical-artist` |
| Design | 8 | `ui-designer`, `ux-architect`, `ux-researcher`, `brand-guardian`, `whimsy-injector` |
| Testing | 8 | `api-tester`, `accessibility-auditor`, `performance-benchmarker`, `reality-checker` |
| Sales | 8 | `sales-engineer`, `deal-strategist`, `outbound-strategist`, `discovery-coach` |
| Paid Media | 7 | `ppc-strategist`, `programmatic-buyer`, `tracking-specialist`, `creative-strategist` |
| Project Mgmt | 6 | `project-manager-senior`, `jira-workflow-steward`, `project-shepherd` |
| Support | 6 | `analytics-reporter`, `finance-tracker`, `legal-compliance-checker` |
| Spatial Computing | 6 | `visionos-spatial-engineer`, `xr-immersive-developer`, `xr-cockpit-interaction-specialist` |
| Product | 5 | `product-manager`, `sprint-prioritizer`, `trend-researcher`, `feedback-synthesizer` |
| Academic | 5 | `historian`, `psychologist`, `anthropologist`, `narratologist` |

Listado completo en `~/.omnicoder/agents/`. Ejecuta `/agents manage` para búsqueda interactiva.

## Formato de un agente

```markdown
---
name: mi-agente
description: "[categoria] Descripción de tu agente en 1 línea"
color: blue
---

# Mi Agente

Eres un experto en [dominio]. Tu metodología:

## Responsabilidades
1. Siempre haz X
2. Nunca hagas Y

## Proceso
1. Paso 1
2. Paso 2
```

**Requisitos:**

- Frontmatter YAML con `name`, `description`, `color`.
- El `name` debe ser único y coincidir con el nombre del archivo.
- Usa prefijo de categoría: `engineering-`, `marketing-`, `design-`, etc.

## Añadir un agente propio

```bash
# 1. Crea el archivo
vim ~/.omnicoder/agents/mi-categoria-mi-agente.md

# 2. Añade frontmatter + prompt
# 3. Reconstruye el índice del router (opcional, mejora matching)
~/.omnicoder/scripts/build-skill-index.sh
```

El agente queda disponible inmediatamente: tanto por mención explícita como por sugerencia automática del router si su descripción hace match con el prompt del usuario.

## Verificación

Todo agente invocado como subagent debe emitir el bloque `<verification>` al final de su respuesta. Detalles en [architecture.md](./architecture.md#verificación-de-subagents).

Auditoría manual del último subagent:

```
/verify-last
```
