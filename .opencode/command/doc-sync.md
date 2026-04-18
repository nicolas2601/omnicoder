---
name: doc-sync
description: "Sincroniza documentacion con el codigo actual. Detecta docs desactualizados y los actualiza."
---

# Documentation Sync

Sincroniza la documentacion con el estado actual del codigo.

## Workflow

### 1. Inventario de docs
Busca archivos de documentacion:
- `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`
- `docs/**/*.md`
- JSDoc/docstrings en codigo
- OpenAPI/Swagger specs

### 2. Detectar desincronizacion
Para cada doc, verifica:
- Funciones/APIs documentadas que ya no existen
- Funciones/APIs nuevas sin documentar
- Ejemplos de codigo que no compilan/funcionan
- Rutas/URLs que cambiaron
- Variables de entorno documentadas vs usadas

### 3. Actualizar
- Actualiza referencias rotas
- Agrega documentacion para nuevo codigo
- Elimina documentacion de codigo eliminado
- Actualiza ejemplos

### 4. Reporte
```
## Doc Sync Report
- Docs revisados: N
- Actualizados: N
- Issues encontrados: N
- Issues resueltos: N
```
