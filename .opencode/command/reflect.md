---
name: reflect
description: Auto-reflexion manual sobre la sesion actual. Destila lecciones de errores, exitos e ignorados.
---

# /reflect — Reflexión manual

Dispara una reflexión estilo Reflexion (Shinn et al. 2023) sobre la sesión actual.

## Qué hago

1. Leo `~/.omnicoder/memory/learned.md` (errores recientes).
2. Leo `~/.omnicoder/memory/trajectories.md` (éxitos recientes).
3. Leo `~/.omnicoder/memory/ignored-skills.md` (skills que ignoré).
4. Extraigo 3-5 lecciones concretas.
5. Las anexo a `~/.omnicoder/memory/reflections.md`.
6. Si la lección es generalizable → la promuevo a `~/.omnicoder/memory/patterns.md`.

## Formato de salida

```
## Reflexión YYYY-MM-DD HH:MM

**Éxitos**: [top 3 patrones]
**Errores**: [top 3 problemas]
**Skills ignorados**: [top 3 con conteo]

**Lecciones**:
1. ...
2. ...
3. ...

**Promovidas a patterns.md**: [si aplica]
```

## Uso

`/reflect` — sin argumentos, analiza últimas 24h.
`/reflect --week` — últimos 7 días.
`/reflect --all` — todo el historial.
