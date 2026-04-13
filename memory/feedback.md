# Feedback del Usuario

Preferencias y correcciones durables. Anadir entradas con el formato:

```
## YYYY-MM-DD | tema
- **Regla**: ...
- **Why**: ...
- **Apply**: ...
```

---

## 2026-04-13 | idioma
- **Regla**: Responder siempre en espanol.
- **Why**: Preferencia del usuario para toda comunicacion.
- **Apply**: En todo output, incluyendo commits y PRs salvo que se pida explicito.

## 2026-04-13 | uso de skills
- **Regla**: Usar activamente el skill-router y find-skills cuando la tarea sea especializada. No responder con solucion generica si hay skill/agente dedicado.
- **Why**: El usuario instalo 193 skills y 168 agentes para esto; no aprovecharlos es desperdicio.
- **Apply**: Antes de ejecutar una tarea especializada (SEO, review, refactor, UI, mobile, etc.), revisa la sugerencia del skill-router y si no hay match invoca /skills find-skills.
