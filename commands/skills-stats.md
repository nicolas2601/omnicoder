---
name: skills-stats
description: Estadisticas de uso de skills: cuales se usan, cuales se ignoran, cuales nunca se activan.
---

# /skills-stats — Estadísticas de skills

Analiza `~/.qwen/memory/skill-stats.json` + `ignored-skills.md` para mostrar:

## Reporte

```
TOP SKILLS USADOS (últimos 30 días)
1. skill-X → 45 usos, 2 ignoradas (96% hit rate)
2. skill-Y → 30 usos, 0 ignoradas (100% hit rate)
...

TOP SKILLS IGNORADOS (oportunidades de mejora)
1. skill-Z → ignorado 8x con score promedio 4.2
   → Router v3 lo elevará a OBLIGATORIO automáticamente
2. ...

SKILLS ZOMBIE (instalados pero nunca usados)
- skill-A, skill-B, skill-C (candidatos a desinstalar)

COBERTURA
- 193 skills instalados, 47 usados alguna vez (24%)
- Recomendación: audit con /skills find-skills para descubrir gaps
```

## Opciones

- `/skills-stats` — Reporte completo.
- `/skills-stats --top 10` — Solo top 10.
- `/skills-stats --ignored` — Solo ignorados.
- `/skills-stats --zombies` — Solo los nunca usados.
- `/skills-stats --reset` — Reinicia contadores (pide confirmación).
