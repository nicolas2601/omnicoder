---
name: audit
description: "Auditoria completa del proyecto: seguridad, performance, accesibilidad, dependencias y code quality."
---

# Audit - Auditoria Completa

Ejecuta una auditoria multi-dimension del proyecto.

## Dimensiones de Auditoria

### 1. Seguridad
- Buscar secrets hardcodeados: API keys, passwords, tokens
- Verificar .gitignore incluye .env, credentials, keys
- Detectar dependencias con vulnerabilidades conocidas (`npm audit` / `pip audit`)
- Revisar input validation en endpoints y formularios
- Verificar headers de seguridad (CSP, CORS, HSTS)

### 2. Performance
- Detectar N+1 queries en ORM/database calls
- Buscar loops anidados con complejidad O(n^2) o peor
- Verificar lazy loading de assets/componentes pesados
- Revisar indices de base de datos
- Buscar memory leaks (event listeners, subscriptions sin cleanup)

### 3. Code Quality
- Archivos >500 lineas (candidatos a split)
- Funciones >50 lineas (candidatos a refactor)
- Complejidad ciclomatica alta
- Codigo duplicado
- Dead code (exports no usados, funciones sin llamadores)

### 4. Dependencias
- Dependencias outdated (`npm outdated` / `pip list --outdated`)
- Dependencias no usadas
- Dependencias con licencias incompatibles
- Bundle size impact de cada dependencia

### 5. Testing
- Cobertura de tests (archivos sin tests)
- Tests faltantes para paths criticos
- Tests fragiles (dependen de estado externo)

## Output Format
```
# Auditoria - [proyecto] - [fecha]

## Puntuacion: [0-100]/100

### Seguridad: [score]/20
[findings]

### Performance: [score]/20
[findings]

### Code Quality: [score]/20
[findings]

### Dependencias: [score]/20
[findings]

### Testing: [score]/20
[findings]

## Top 5 Acciones Prioritarias
1. [P0] ...
2. [P0] ...
3. [P1] ...
4. [P1] ...
5. [P2] ...
```
