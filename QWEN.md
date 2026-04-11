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

## Slash Commands Personalizados

Los siguientes commands estan disponibles en `~/.qwen/commands/`:

| Comando | Descripcion |
|---------|-------------|
| `/review` | Code review del diff actual con checklist P0-P3 |
| `/ship` | Pre-flight check: tests + lint + review + commit + push |
| `/handoff` | Genera documento de handoff para continuidad entre sesiones |
| `/audit` | Auditoria completa: seguridad, performance, accesibilidad |
| `/refactor` | Refactor inteligente con verificacion de regresiones |
| `/test-gen` | Genera tests automaticamente para codigo sin cobertura |
| `/doc-sync` | Sincroniza documentacion con el codigo actual |
| `/perf` | Analisis de performance con metricas actionables |
| `/deps` | Analiza dependencias: outdated, vulnerables, unused |
| `/plan` | Planificacion estructurada con decomposicion de tareas |
| `/compact` | Compresion inteligente con handoff automatico |
| `/stats` | Estadisticas de sesion: tokens, cache hits, tiempo |

## Hooks Activos

Los hooks en `settings.json` proporcionan:
- **PreToolUse**: Validacion de seguridad (bloquea paths peligrosos, secrets)
- **PostToolUse**: Logging de operaciones para auditoria
- **SessionStart**: Carga contexto del ultimo handoff automaticamente
- **Stop**: Genera handoff si la sesion fue productiva
- **UserPromptSubmit**: Auto-routing de skills basado en intent del prompt
