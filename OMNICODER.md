# OmniCoder (v4.3)

Espanol siempre. Detalle completo: `docs/architecture.md`, `docs/skills.md`, `docs/hooks.md`.

## Niveles de complejidad

| Nivel | % | Estrategia |
|---|---|---|
| 1 | <30 | Edit directo. Sin subagent |
| 2 | 30-70 | 1 subagent con contexto minimo |
| 3 | >70 | 3-5 subagents en paralelo |

## Reglas no negociables

- Lee archivo antes de editar. Tests despues de cambios. Inputs validados en boundaries
- Nunca: hardcodear secrets, commitear `.env`, lanzar subagents en Nivel 1, repetir contexto ya cargado
- Agrupa lecturas/escrituras/Bash en un solo mensaje
- Aceptar reporte de subagent sin `<verification>` esta prohibido

## Verificacion de subagents (contrato)

Todo subagent debe cerrar con:
```
<verification>
files: [...]
commands: [...]
tests: true|false
summary: ...
</verification>
```
Si ves `[VERIFICACION-FALLIDA]`: no reportes "listo", re-audita con `Read`+`git diff --stat` o `/verify-last`. Detalle: `docs/architecture.md#verificacion`.

## Enforcement de skills

| Marker | Accion |
|---|---|
| `[OBLIGATORIO]` | Invoca el skill/agente. No improvises |
| `[SUGERIDO]` | Usalo salvo razon fuerte (documentar motivo) |
| `[HINT]` / `[BUSCAR-SKILL]` | `npx skills find <query>` o `/skills find-skills` |
| `[TECH:X]` | Hay tech detectada. Hay candidatos locales o en npm |

Tareas multi-dominio: 2-3 agentes en paralelo via Task. Nunca resuelvas a mano algo que tiene skill dedicado.

## Flujo obligatorio (tarea nueva)

1. Router auto-escanea 193 skills + 168 agentes. Lee el marker inyectado
2. Sin match local y dominio especializado: `npx skills find <terminos>`. Instala con `npx skills add <owner/repo@skill> -g -y`
3. Solo despues improvisa

## Catalogo

Skills por dominio y agentes: `docs/skills.md`. Slash commands: `docs/commands.md`. Hooks activos: `docs/hooks.md`. Memoria dual + router scoring + reflexion: `docs/architecture.md`.
