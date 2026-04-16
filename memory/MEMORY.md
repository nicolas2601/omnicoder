# Memoria Global de OmniCoder

Este archivo es el indice maestro de memoria persistente. Lo carga `memory-loader.sh` en cada `SessionStart`.

## Archivos en ~/.omnicoder/memory/

- `MEMORY.md` (este) - Indice maestro, < 200 lineas
- `feedback.md` - Preferencias explicitas del usuario (editable a mano)
- `learned.md` - Errores detectados automaticamente por error-learner.sh
- `project_<nombre>.md` - Memoria de proyectos especificos

## Que se guarda aqui

**SI:**
- Preferencias durables ("siempre responde en espanol", "usa tabs no spaces")
- Errores recurrentes que no quieres repetir
- Contexto de proyectos en los que trabajas frecuentemente
- Decisiones de arquitectura y por que

**NO:**
- Secrets, tokens, credenciales
- Informacion transitoria de una sola conversacion
- Contenido que se puede derivar leyendo el codigo actual

## Como actualizarla

- **Automatico**: errores -> `learned.md` (via hook), sugerencias de skills se registran implicitamente
- **Semi-automatico**: `/learn` analiza el proyecto y escribe `./.omnicoder/memory/project.md`
- **Manual**: edita `feedback.md` directamente o usa `/memory`

## Principios

1. Memoria = contexto inyectado al inicio de cada sesion. Mantenerla corta.
2. Si una regla esta en memoria, OmniCoder debe respetarla sin que el usuario la repita.
3. Memoria obsoleta es peor que memoria ausente: limpia con `/memory clean`.
