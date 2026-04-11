---
name: refactor
description: "Refactor inteligente con verificacion automatica de regresiones. Propone, ejecuta y valida cambios."
---

# Refactor Inteligente

Refactoriza codigo de forma segura con verificacion de regresiones.

## Workflow

### 1. Identificar scope
- Que archivo(s) o funcion(es) refactorizar
- Por que (complejidad, duplicacion, legibilidad, performance)

### 2. Snapshot pre-refactor
```bash
git stash  # Guardar cambios no commiteados si los hay
```
Ejecutar tests para confirmar que pasan ANTES del refactor.

### 3. Proponer cambios
Describe los cambios propuestos ANTES de ejecutarlos:
- Que se va a cambiar
- Por que mejora el codigo
- Que riesgos hay

### 4. Ejecutar refactor
Aplica los cambios de forma incremental:
- Un cambio logico a la vez
- Mantener funcionalidad identica (no agregar features)
- Preservar interfaces publicas

### 5. Verificar
```bash
# Ejecutar tests
npm test  # o equivalente

# Verificar que no hay regresiones en tipos
npx tsc --noEmit  # TypeScript
```

### 6. Si los tests fallan
- Revertir el ultimo cambio
- Analizar por que fallo
- Intentar approach diferente

### 7. Reporte
```
## Refactor Completado
- Archivos: [N] modificados
- Tests: PASS
- Cambios: [resumen de mejoras]
- Metricas: [lineas antes] -> [lineas despues]
```
