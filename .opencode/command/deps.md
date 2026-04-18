---
name: deps
description: "Analiza dependencias del proyecto: outdated, vulnerables, unused, y peso del bundle."
---

# Dependency Analyzer

Analisis completo de dependencias del proyecto.

## Checks

### 1. Vulnerabilidades
```bash
npm audit 2>/dev/null || pip audit 2>/dev/null || cargo audit 2>/dev/null
```

### 2. Dependencias desactualizadas
```bash
npm outdated 2>/dev/null || pip list --outdated 2>/dev/null
```

### 3. Dependencias no utilizadas
Busca imports en el codigo fuente y compara con dependencias declaradas:
- Dependencias en package.json/requirements.txt que no se importan en ningun archivo
- devDependencies que podrian ser dependencies (o viceversa)

### 4. Peso del bundle (Node.js)
```bash
npx cost-of-modules 2>/dev/null || true
```

### 5. Licencias
Verifica compatibilidad de licencias:
- MIT, Apache-2.0, BSD: OK
- GPL, AGPL: Requiere atencion
- Sin licencia: Riesgo

### Output
```
## Dependency Report - [fecha]

### Vulnerabilidades: [N criticas, N altas, N medias]
[tabla de CVEs]

### Desactualizadas: [N]
| Paquete | Actual | Ultima | Tipo |
|---------|--------|--------|------|

### No Utilizadas: [N]
[lista de dependencias candidatas a eliminar]

### Acciones Recomendadas
1. [urgente] Fix: npm audit fix
2. [importante] Update: [paquete] a [version]
3. [opcional] Remove: [paquete] (no utilizado)
```
