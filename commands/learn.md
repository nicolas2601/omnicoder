---
name: learn
description: "Aprende sobre el proyecto actual y guarda memoria persistente en ~/.omnicoder/memory/ y ./.omnicoder/memory/"
---

# /learn - Aprender y Persistir Memoria

Cuando el usuario invoca `/learn`, ejecuta este workflow para construir memoria persistente que el sistema cargara automaticamente en proximas sesiones via `memory-loader.sh`.

## Objetivo

Construir un modelo mental del proyecto y del usuario, y guardarlo como markdown en dos lugares:

- **Global** (`~/.omnicoder/memory/`): preferencias del usuario, feedback, errores recurrentes.
- **Proyecto** (`./.omnicoder/memory/`): stack, convenciones, archivos clave, comandos de build/test/lint, decisiones de arquitectura.

## Workflow

### Paso 1: Analizar proyecto actual

1. Lee (si existen): `README.md`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `tsconfig.json`, `.env.example`, `CLAUDE.md`, `OMNICODER.md`, `AGENTS.md`.
2. Ejecuta: `git log --oneline -20`, `git branch --show-current`, `ls -la`.
3. Identifica stack, framework, comandos de test/lint/build, patrones de carpetas.

### Paso 2: Extraer insights

Responde internamente (no al usuario):

- **Que hace el proyecto?** (una frase)
- **Stack y herramientas clave**
- **Comandos de desarrollo** (build, test, lint, dev server)
- **Convenciones** (nombrado, estructura, testing framework)
- **Archivos criticos** (entry points, config, schemas)
- **Deuda tecnica o warnings obvios**

### Paso 3: Escribir memoria del proyecto

Crea `./.omnicoder/memory/project.md`:

```markdown
---
updated: {{YYYY-MM-DD}}
---

# Proyecto: {{nombre}}

## Que es
{{una frase}}

## Stack
- Lenguaje: ...
- Framework: ...
- Package manager: ...
- Test: ...

## Comandos Clave
\`\`\`bash
# Dev
{{comando}}
# Test
{{comando}}
# Lint
{{comando}}
# Build
{{comando}}
\`\`\`

## Estructura
- `src/` - ...
- `tests/` - ...
- `config/` - ...

## Convenciones
- ...

## Archivos Criticos
- `{{path}}:{{line}}` - {{por que importa}}

## Notas / Gotchas
- ...
```

### Paso 4: Actualizar memoria global (opcional)

Si durante la conversacion aprendiste algo sobre las preferencias del usuario (no sobre el proyecto):

Actualiza `~/.omnicoder/memory/feedback.md` con una entrada nueva:

```markdown
## {{YYYY-MM-DD}} - {{tema}}
{{preferencia observada}}
**Why**: {{razon si la dio}}
**Apply**: {{cuando aplicar}}
```

### Paso 5: Confirmar

Responde al usuario en 2-3 lineas:
- Que guardaste y donde
- Que va a cargar automaticamente la proxima sesion
- Como borrar/editar si quiere

## Reglas

- NO crees archivos de memoria si el proyecto tiene <5 archivos (probablemente no vale la pena).
- NO guardes secrets, tokens, rutas absolutas de usuario.
- SIEMPRE usa frontmatter con `updated:` para poder detectar memoria vieja.
- Si `./.omnicoder/memory/project.md` ya existe, lee primero y actualiza solo secciones que cambiaron.
- Si el usuario especifica un foco (`/learn stack`, `/learn convenciones`), solo actualiza esa seccion.

## Ejemplos de invocacion

```
/learn              # Aprende todo del proyecto
/learn stack        # Solo stack y herramientas
/learn convenciones # Solo patrones/naming
/learn user         # Solo memoria global del usuario
```
