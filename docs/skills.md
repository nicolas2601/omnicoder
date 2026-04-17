# Skills

## Skills vs agentes

| Aspecto | Skill | Agente |
|---------|-------|--------|
| **Qué es** | Paquete de conocimiento + procedimiento reusable | Experto de dominio con system prompt |
| **Ubicación** | `~/.omnicoder/skills/<nombre>/SKILL.md` | `~/.omnicoder/agents/<nombre>.md` |
| **Invocación** | `/skills <nombre>` o auto-router | Mención en conversación o `Task` tool |
| **Contiene** | Instrucciones, checklists, scripts, ejemplos | Rol, metodología, reglas |
| **Ejecución** | En el modelo principal | Subagent aislado (Task) |
| **Cuándo usar** | Workflows repetitivos (code-review, QA, SEO) | Tareas especializadas de dominio |

Los skills son más granulares: describen un procedimiento. Los agentes son más pesados: adoptan una identidad completa de experto.

## Invocación

### Automática (via router)

El `skill-router.sh` analiza cada prompt con BM25 + bigramas + memoria. Si el match es fuerte emite `[OBLIGATORIO]`. Si es medio, `[SUGERIDO]`. El agente debe invocar el skill antes de improvisar.

### Manual

```
/skills <nombre>

Ejemplo:
/skills code-review
/skills audit-website
/skills ui-ux-pro-max
```

## Skills principales instalados

OmniCoder trae 193 skills. Los 18 más usados:

| Skill | Función |
|-------|---------|
| `code-review` | Review con checklist P0-P3 |
| `comprehensive-review` | Review multi-subagent en paralelo (alto coste) |
| `review` | Pre-landing PR review contra base branch |
| `audit-website` | Auditoría web: SEO, perf, seguridad (230+ reglas, squirrelscan) |
| `maestro` | Gestión de repos complejos con 12 sub-skills |
| `ui-ux-pro-max` | Diseño UI/UX: 50 estilos, 21 paletas, 50 font pairings |
| `frontend-design` | Interfaces production-grade |
| `web-design-guidelines` | Auditoría UI Web Interface Guidelines |
| `playwright` | Automatización de browser |
| `browse` / `gstack` | Headless browser para QA, ~100ms/cmd |
| `qa` / `qa-only` | QA iterativo (fix + verify) o reporte |
| `gemini` | Code review con contexto grande (>200k) |
| `vercel-react-best-practices` | Optimización React/Next.js (Vercel Engineering) |
| `react-native-best-practices` | FPS, TTI, bundle, memory en RN |
| `nano-banana-pro` | Generación de imágenes con Gemini 2.5 Flash |
| `seo` | SEO completo: audit, technical, content, GEO |
| `ship` | Pipeline completo: tests + lint + commit + push |
| `find-skills` | Descubrir e instalar skills del ecosistema |

Listado completo en `~/.omnicoder/skills/` o con `/skills-stats`.

## Instalar skills externas

El ecosistema de skills es extensible. Para instalar desde registros públicos:

```bash
# Buscar
npx skills find <query>

# Instalar globalmente
npx skills add <owner/repo@skill> -g -y

# Ejemplos reales
npx skills add anthropics/claude-code@frontend-design -g -y
npx skills add vercel-labs/web-design-guidelines -g -y
```

Browse del catálogo público: https://skills.sh/

Después de instalar, reconstruye el índice del router:

```bash
~/.omnicoder/scripts/build-skill-index.sh
```

## Crear un skill propio

### Estructura mínima

```
~/.omnicoder/skills/
└── mi-skill/
    ├── SKILL.md        # Obligatorio
    ├── scripts/        # Opcional
    └── templates/      # Opcional
```

### Formato de `SKILL.md`

```markdown
---
name: mi-skill
description: "Qué hace y cuándo usarlo. Cuanto más específico, mejor ranking."
---

# Mi Skill

## Cuándo activar
- Caso de uso 1
- Caso de uso 2

## Procedimiento
1. Paso 1 con comando
2. Paso 2 con criterio de éxito
3. Paso 3 con output esperado

## Checklist
- [ ] Ítem 1
- [ ] Ítem 2
```

### Buenas prácticas

- **Description rica**: el router usa BM25 sobre este campo. Incluye palabras clave del dominio.
- **Triggers explícitos**: qué prompts deben activarlo (ej. "usa cuando el usuario dice 'audit my site'").
- **Procedimiento paso a paso**: no dejes nada a la imaginación.
- **Evidence block**: si el skill lanza subagents, exige `<verification>`.

### Reconstruir índice

```bash
~/.omnicoder/scripts/build-skill-index.sh
```

Tras esto el router lo indexa y puede sugerirlo automáticamente.

## Catalogo por dominio

Lista breve de agentes y skills por dominio. Listado completo: `~/.omnicoder/agents/` y `~/.omnicoder/skills/`.

| Dominio | Agentes principales | Skills |
|---------|--------------------|---------|
| **Desarrollo** | `engineering-backend-architect`, `engineering-frontend-developer`, `engineering-software-architect`, `engineering-code-reviewer`, `engineering-devops-automator`, `engineering-database-optimizer`, `engineering-security-engineer`, `engineering-mobile-app-builder` | `code-review`, `comprehensive-review`, `vercel-react-best-practices`, `react-native-best-practices`, `django-expert` |
| **Diseno** | `design-ui-designer`, `design-ux-architect`, `design-ux-researcher`, `design-brand-guardian` | `ui-ux-pro-max`, `frontend-design`, `web-design-guidelines`, `nano-banana-pro` |
| **Testing** | `testing-api-tester`, `testing-accessibility-auditor`, `testing-performance-benchmarker`, `testing-workflow-optimizer` | `qa`, `qa-only`, `playwright`, `browse`, `gstack` |
| **Marketing** | `marketing-seo-specialist`, `marketing-content-creator`, `marketing-growth-hacker`, `marketing-tiktok-strategist`, `marketing-linkedin-content-creator` | `seo`, `seo-audit`, `seo-content`, `seo-geo`, `audit-website` |
| **Producto** | `product-manager`, `product-sprint-prioritizer`, `product-feedback-synthesizer` | `plan`, `plan-eng-review`, `plan-ceo-review` |
| **Ventas** | `sales-engineer`, `sales-deal-strategist`, `sales-outbound-strategist` | — |
| **Game Dev** | `unity-architect`, `unreal-systems-engineer`, `godot-gameplay-scripter`, `game-designer` | — |
| **Release** | — | `ship`, `document-release`, `retro` |
| **Meta** | — | `find-skills`, `skill-builder`, `skill-creator`, `maestro` |
