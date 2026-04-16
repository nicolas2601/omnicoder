---
name: memory
description: "Gestiona la memoria persistente: listar, ver, editar, limpiar o exportar"
---

# /memory - Gestor de Memoria Persistente

Herramienta para inspeccionar y mantener la memoria que OmniCoder carga en cada sesion.

## Ubicaciones

- **Global**: `~/.omnicoder/memory/`
  - `MEMORY.md` - indice maestro
  - `feedback.md` - preferencias del usuario
  - `learned.md` - errores aprendidos (auto-generado por error-learner.sh)
  - `project_*.md` - memoria de proyectos especificos
- **Proyecto actual**: `./.omnicoder/memory/*.md`

## Subcomandos

### `/memory list`
Muestra todos los archivos de memoria con tamano y fecha de modificacion.

```bash
ls -lh ~/.omnicoder/memory/ 2>/dev/null
ls -lh ./.omnicoder/memory/ 2>/dev/null
```

### `/memory show <archivo>`
Imprime el contenido. Ejemplos:
- `/memory show feedback`
- `/memory show learned`
- `/memory show project`

### `/memory forget <pattern>`
Elimina entradas que matcheen `pattern` de `learned.md` o `feedback.md`. Pide confirmacion antes de borrar.

### `/memory clean`
Elimina entradas de `learned.md` con mas de 30 dias o con sig duplicado.

### `/memory stats`
Cuenta entradas por archivo, errores mas frecuentes, skills mas sugeridos.

### `/memory export`
Crea un tar.gz en `~/.omnicoder/memory-export-{fecha}.tar.gz` con toda la memoria (para backup).

### `/memory import <archivo.tar.gz>`
Restaura un export previo (merge, no sobreescribe).

## Workflow cuando el usuario invoca /memory sin argumentos

1. Ejecuta `list` para mostrar todos los archivos
2. Ejecuta `stats` para resumen
3. Pregunta al usuario que quiere hacer

## Reglas

- NUNCA borres archivos sin confirmar con el usuario.
- `learned.md` es auto-generado: no edites a mano, usa `/memory forget` o `/memory clean`.
- `feedback.md` y `project_*.md` son editables a mano libremente.
- Si el usuario quiere anadir manualmente una leccion, usa el formato:
  ```markdown
  ### YYYY-MM-DD | manual
  - **Regla**: ...
  - **Why**: ...
  - **Apply**: ...
  ```
