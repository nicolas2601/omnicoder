---
name: personality
description: Activa un alter-ego viltrumita (Omni-Man, Conquest, Thragg, Anissa, Cecil, Immortal). Cambia el tono sin afectar calidad tecnica.
---

# /personality - Alter-ego viltrumita

## Instrucciones al modelo (IMPERATIVO — NO desviar)

Cuando el usuario invoque `/personality <args>`:

1. **NO muestres bloques `<think>`** ni explicaciones de tu razonamiento.
2. **NO decores la salida** con ASCII art propio ni tablas custom.
3. **NO preguntes al usuario** "¿quieres que active alguna?" ni ofrezcas seguimientos.
4. **NO menciones deteccion de tecnologias** (Vue, React, etc) ni skills externas.
5. **Ejecuta inmediatamente** el siguiente shell y muestra su salida **tal cual**:

```bash
bash ~/.omnicoder/scripts/personality.sh <ARGS_DEL_USUARIO>
```

Reemplaza `<ARGS_DEL_USUARIO>` por los argumentos que siguieron a `/personality`.
Si el usuario solo escribio `/personality` sin args, ejecuta `bash ~/.omnicoder/scripts/personality.sh help`.

6. **Despues de mostrar la salida del script**, no agregues texto adicional. El script ya imprime confirmacion con colores — no hace falta resumir ni adornar.

## Argumentos validos

| Subcomando | Accion |
|------------|--------|
| `set <nombre>` | Activa personalidad. Nombres: omni-man, conquest, thragg, anissa, cecil, immortal. Aliases: omniman, nolan, emperador, etc |
| `get` | Muestra la personalidad actualmente activa |
| `list` | Lista todas las personalidades con descripcion |
| `off` | Desactiva (vuelve a OmniCoder estandar) |
| `random` | Elige una personalidad al azar |

## Ejemplos

```
/personality list
/personality set omni-man
/personality set conquest
/personality random
/personality off
```

## Detalle tecnico (para tu referencia, NO mostrar al usuario salvo que pregunte)

- El script lee/escribe `~/.omnicoder/.personality`.
- El hook `personality-injector.sh` (UserPromptSubmit) lee ese archivo y añade al contexto de prompts siguientes las reglas de tono del personaje activo.
- El cambio es persistente entre sesiones hasta hacer `/personality off`.
- Para que el cambio surta efecto en la conversacion actual, el siguiente mensaje del usuario ya trae la personalidad aplicada via hook.
