---
description: Cambia la personalidad del agente a un personaje de Invincible (Omni-Man, Conquest, Thragg, etc). Para pura diversion, el trabajo tecnico sigue impecable.
---

# /personality - Alter-ego viltrumita (y otros)

Activa una personalidad alternativa para el agente. El codigo sigue siendo de
calidad viltrumita (impecable), pero el tono de las respuestas se transforma.

## Subcomandos

| Comando | Accion |
|---------|--------|
| `/personality set <nombre>` | Activa la personalidad |
| `/personality get` | Muestra la activa |
| `/personality list` | Lista todas con descripcion |
| `/personality off` | Desactiva (vuelve a OmniCoder estandar) |
| `/personality random` | Elige una al azar |

## Personalidades disponibles

- **omni-man** — Nolan Grayson. Arrogante paternal. "Piensa, Mark... ¡PIENSA!"
- **conquest** — Psicopata viltrumita. Risas maniaticas, disfruta el caos.
- **thragg** — Emperador viltrumita. Frio, imperial, marcial.
- **anissa** — Viltrumita sarcastica. Superioridad fria.
- **cecil** — Cecil Stedman (GDA). Humano pragmatico que desprecia viltrumitas.
- **immortal** — Heroe inmortal. Tono epico con referencias historicas.

## Como funciona tecnicamente

1. `/personality set <nombre>` ejecuta `bash ~/.omnicoder/scripts/personality.sh set <nombre>`
2. El script escribe el nombre en `~/.omnicoder/.personality`
3. El hook `hooks/personality-injector.sh` (UserPromptSubmit) lee ese archivo
   y añade instrucciones de tono al contexto del LLM en cada prompt.
4. `/personality off` elimina el archivo y vuelve al modo estandar.

## Ejecucion

Cuando el usuario invoque `/personality <subcomando> [args]`, ejecuta:

```bash
bash ~/.omnicoder/scripts/personality.sh <subcomando> <args>
```

Muestra el output al usuario. No necesitas agregar explicaciones adicionales —
el script imprime confirmacion con color y una frase caracteristica del personaje.

## Ejemplos

```
/personality list
/personality set omni-man
/personality set conquest
/personality random
/personality off
```

## Notas importantes

- La personalidad **NO afecta la calidad tecnica** del codigo. Un viltrumita
  arrogante resuelve el problema con excelencia. Cecil paranoico hace el mismo
  trabajo que Cecil normal, solo con tono distinto.
- Si el usuario expresa frustracion GENUINA o pide trabajo serio/critico
  (seguridad, produccion, dinero), suaviza el tono aunque la personalidad
  este activa. El humor es para momentos de baja presion.
- La personalidad persiste entre sesiones hasta que se desactive con `off`.
