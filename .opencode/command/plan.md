---
name: plan
description: "Planificacion estructurada con decomposicion de tareas, estimacion de complejidad, y dependencias."
---

# Plan - Planificacion Estructurada

Descompone una tarea compleja en pasos ejecutables.

## Workflow

### 1. Entender el objetivo
- Que se quiere lograr exactamente
- Cuales son los constraints (tiempo, tecnologia, compatibilidad)
- Que ya existe vs que hay que crear

### 2. Explorar el codebase
- Leer archivos relevantes al objetivo
- Identificar dependencias y puntos de integracion
- Detectar posibles conflictos o riesgos

### 3. Descomponer en tareas
Para cada tarea:
- Titulo claro y actionable
- Descripcion de que hacer
- Archivos a modificar
- Complejidad: baja/media/alta
- Dependencias: que tareas deben completarse antes

### 4. Output
```
## Plan: [Titulo del Objetivo]

### Contexto
[1-2 parrafos sobre el estado actual y el objetivo]

### Tareas
| # | Tarea | Complejidad | Dependencias | Archivos |
|---|-------|------------|-------------|----------|
| 1 | ... | Baja | - | file.ts |
| 2 | ... | Media | #1 | api.ts, db.ts |
| 3 | ... | Alta | #1, #2 | ... |

### Riesgos
- [Riesgo 1]: [Mitigacion]

### Orden de Ejecucion Recomendado
1. [Tarea] - [razon de prioridad]
2. ...

### Estimacion
- Tareas totales: N
- Complejidad promedio: [baja/media/alta]
```
