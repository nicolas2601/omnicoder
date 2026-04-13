---
name: patterns
description: Gestionar patrones semanticos aprendidos. Ver, editar, eliminar, promover.
---

# /patterns — Gestión de patrones semánticos

Gestiona `~/.qwen/memory/patterns.md`: las reglas destiladas que el router carga en contexto.

## Subcomandos

- `/patterns list` — Lista todos los patrones activos.
- `/patterns show <id>` — Detalle de un patrón.
- `/patterns add "<regla>" --why "<razón>" --apply "<cuándo>"` — Añade manualmente.
- `/patterns forget <id>` — Elimina un patrón obsoleto.
- `/patterns distill` — Fuerza destilación desde trayectorias → patrones.
- `/patterns stats` — Cuántos patrones, cuáles están activos, cuáles nunca se consultaron.

## Filosofía

Los patrones son **semantic memory** (reglas generales) destiladas desde **episodic memory** (casos específicos en `trajectories.md` y `learned.md`).

Un patrón bueno:
- Es generalizable (aplica a N casos, no a 1 específico).
- Tiene "why" clara (razón detrás, no solo la regla).
- Tiene "apply" concreto (cuándo dispararlo).

Un patrón malo (elimina):
- Muy específico (referencia a un archivo/proyecto concreto).
- Nunca se activa (0 consultas en 30 días).
- Contradice otro patrón más reciente.
