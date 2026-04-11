---
name: perf
description: "Analisis de performance del proyecto con metricas actionables. Detecta bottlenecks y sugiere optimizaciones."
---

# Performance Analyzer

Analisis de performance con recomendaciones concretas.

## Areas de Analisis

### 1. Complejidad Algoritmica
Busca en el codigo:
- Loops anidados (O(n^2) o peor)
- Operaciones en arrays grandes sin paginacion
- Regex complejos en hot paths
- Sorting repetitivo sin cache

### 2. Database / IO
- N+1 queries (loop con query dentro)
- Queries sin indice (full table scan)
- Falta de connection pooling
- Lecturas sincronas de archivos grandes

### 3. Memory
- Event listeners sin removeEventListener
- Subscriptions sin unsubscribe
- Closures que retienen referencias grandes
- Arrays/Maps que crecen sin limite

### 4. Bundle / Load Time (Frontend)
- Imports dinamicos faltantes (code splitting)
- Imagenes sin lazy loading
- CSS/JS sin minificar
- Fonts blocking render

### 5. Concurrencia
- Operaciones async que podrian ser paralelas (Promise.all)
- Locks excesivos o falta de locks
- Blocking operations en event loop

### Output
```
## Performance Report

### Hotspots Detectados
| Archivo:Linea | Issue | Impacto | Fix |
|--------------|-------|---------|-----|

### Quick Wins (alto impacto, bajo esfuerzo)
1. ...

### Optimizaciones Mayores
1. ...
```
