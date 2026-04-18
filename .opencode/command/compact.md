---
name: compact
description: "Compresion inteligente de contexto con handoff automatico. Guarda progreso antes de comprimir."
---

# Smart Compact

Comprime el contexto de forma inteligente preservando el progreso.

## Workflow

### 1. Evaluar estado actual
- Revisar que tareas estan en progreso
- Identificar decisiones importantes tomadas
- Listar archivos modificados en esta sesion

### 2. Generar handoff automatico
Antes de comprimir, crea un handoff con todo el contexto critico:
- Archivo: `.omnicoder/handoff-{timestamp}.md`
- Contenido: objetivo, progreso, decisiones, proximos pasos

### 3. Comprimir
Ejecuta `/compress` con un resumen que incluya:
- Objetivo principal de la sesion
- Estado actual del trabajo
- Referencia al handoff: "Ver .omnicoder/handoff-{timestamp}.md para contexto completo"

### 4. Confirmar
Informa al usuario:
- Handoff guardado en: [path]
- Contexto comprimido exitosamente
- Para retomar: "lee [path del handoff]"
