---
name: review
description: "Code review estructurado del diff actual con checklist P0-P3. Detecta bugs, security issues, performance problems y code smells."
---

# Code Review Profesional

Ejecuta un code review completo del diff actual.

## Workflow

### Paso 1: Obtener el diff
```bash
git diff HEAD~1..HEAD
```
Si no hay commits recientes, usa `git diff` para cambios no commiteados.

### Paso 2: Leer archivos completos afectados
Lee cada archivo modificado para entender el contexto completo, no solo los hunks del diff.

### Paso 3: Analizar con checklist

#### P0 - Critico (MUST FIX)
- Vulnerabilidades de seguridad (injection, XSS, secrets expuestos)
- Perdida de datos o corrupcion de estado
- Crashes o errores no manejados en paths criticos

#### P1 - Mayor (MUST FIX)
- Bugs logicos (off-by-one, null handling, race conditions)
- Regresiones de performance (N+1 queries, loops cuadraticos)
- Features rotas o incompletas

#### P2 - Menor (NICE TO FIX)
- Code smells (duplicacion, nombres confusos, complejidad innecesaria)
- Inconsistencias con el estilo del proyecto
- Falta de tipos o validacion en boundaries

#### P3 - Sugerencia (OPCIONAL)
- Mejoras de legibilidad
- Refactors opcionales
- Oportunidades de abstraccion

### Paso 4: Formato de output
```
## Code Review - [fecha]

### Resumen
- Archivos: N modificados
- Riesgo: [bajo/medio/alto]
- Veredicto: [aprobar/aprobar con cambios/rechazar]

### Issues Encontrados
#### P0 - [titulo] (archivo:linea)
Descripcion y fix sugerido

### Lo Bueno
- Aspectos positivos del cambio
```
