---
name: handoff
description: "Genera un documento de handoff para continuidad entre sesiones. Captura estado actual, progreso, y proximos pasos."
---

# Handoff - Documento de Continuidad

Genera un documento de handoff para que la proxima sesion pueda retomar sin perder contexto.

## Instrucciones

1. Analiza la conversacion actual y los cambios realizados
2. Crea el archivo `.qwen/handoff-{YYYYMMDD-HHmm}.md` con este formato:

```markdown
# Handoff - [fecha y hora]

## Objetivo
[Que estabamos intentando lograr]

## Progreso
- [x] Lo que se completo
- [ ] Lo que falta

## Decisiones Tomadas
- [Decision 1]: [Razon]
- [Decision 2]: [Razon]

## Archivos Clave Modificados
- `path/to/file.ts:42` - [que se cambio y por que]

## Lo Que Funciono
- [Enfoque/patron que funciono bien]

## Lo Que NO Funciono
- [Enfoque descartado y por que]

## Proximos Pasos (en orden)
1. [Paso inmediato siguiente]
2. [Paso siguiente]
3. [Paso siguiente]

## Contexto Importante
[Cualquier informacion no obvia que la proxima sesion necesite]
```

3. Confirma al usuario que el handoff fue creado y su ubicacion
