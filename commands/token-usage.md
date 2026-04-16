---
name: token-usage
description: "Muestra estadisticas de uso de tokens estimado por sesion y acumulado"
---

# /token-usage

Dashboard de consumo estimado de tokens.

## Proceso

1. Lee `~/.omnicoder/logs/token-usage.jsonl` (historial completo).
2. Calcula:
   - **Sesion actual**: suma tokens de las ultimas 2 horas (o desde ultimo SessionStart)
   - **Hoy**: suma tokens del dia actual
   - **Semana**: suma tokens de los ultimos 7 dias
   - **Total**: suma de todo el historial
   - **Por tool**: desglose de tokens por herramienta (Bash, Edit, Read, etc.)
   - **Promedio por operacion**: total / numero de operaciones
3. Presenta tabla formateada:

```
TOKEN USAGE - OmniCoder
━━━━━━━━━━━━━━━━━━━━━━━━━━
Sesion:   ~12,500 tokens (43 ops)
Hoy:      ~45,200 tokens (156 ops)
Semana:   ~234,100 tokens (812 ops)
Total:    ~1,234,567 tokens (4,231 ops)

Por herramienta:
  Bash:   45% (~556K)
  Read:   30% (~370K)
  Edit:   15% (~185K)
  Task:   10% (~123K)
```

## Notas
- Los tokens son **estimados** (1 token ≈ 4 caracteres). No es exacto pero da tendencia.
- Si `token-usage.jsonl` no existe, reporta "Sin datos. El tracker se activa automaticamente."
