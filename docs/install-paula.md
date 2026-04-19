# Guía de instalación para Paulasaah (Windows)

## ¿Qué cambió?

Antes: clonar repo + `bun install` + configurar env vars a mano.
Ahora: un solo comando `npm install -g` y listo.

OmniCoder ahora vive en npm como `@nicolas2601/omnicoder`. Instala el
opencode runtime (per-platform binary), 172 agentes, 29 comandos, tema
morado y routing presets automáticamente en tu `%APPDATA%\opencode\`.

## Paso 1 — Eliminar instalación vieja

Abrí PowerShell como **administrador**:

```powershell
# Si tenés el repo clonado de antes:
Remove-Item -Recurse -Force "$env:USERPROFILE\omnicoder-v5" -ErrorAction SilentlyContinue

# Limpiar configuración vieja (OJO: borra tus agents y commands custom si tenías):
Remove-Item -Recurse -Force "$env:USERPROFILE\.omnicoder" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\opencode\agent" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\opencode\command" -ErrorAction SilentlyContinue

# Desinstalar opencode global si lo instalaste en paralelo:
npm uninstall -g opencode-ai
```

## Paso 2 — Verificar Node.js 18+

```powershell
node --version
```

Si sale menos de v18 o error, instalá Node 20 LTS desde
https://nodejs.org/ (marcá "Add to PATH" en el instalador).

## Paso 3 — Instalar OmniCoder

```powershell
npm install -g @nicolas2601/omnicoder@alpha
```

Si tira "access denied" o "EACCES", probá:
```powershell
npm install -g @nicolas2601/omnicoder@alpha --force
```

## Paso 4 — Configurar tu API key

Elegí **una** de estas opciones según tu provider:

```powershell
# NVIDIA NIM (gratis, 40 RPM):
[Environment]::SetEnvironmentVariable("NVIDIA_API_KEY", "nvapi-...", "User")

# Anthropic:
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")

# MiniMax:
[Environment]::SetEnvironmentVariable("MINIMAX_API_KEY", "...", "User")
```

**Cerrá y reabrí PowerShell** para que el env var tome efecto.

## Paso 5 — Lanzar

```powershell
omnicoder
```

Primera vez copia 172 agents y 29 commands a `%APPDATA%\opencode\`. Te
muestra línea tipo `[omnicoder] seeded 172 agents + 29 commands → ...`.

## Comandos útiles

```powershell
omnicoder --version        # ver versión instalada
omnicoder update           # actualizar a la última alpha
omnicoder seed --force     # re-copiar agents/commands si los borraste
omnicoder-routing list     # ver presets de routing por fase
omnicoder-routing apply balanced  # Sonnet plan, Haiku build
omnicoder-routing off      # volver al default
```

## Dentro de la TUI

- `/personality` — abre picker visual con 6 personas (Omni-Man, Conquest,
  Thragg, Anissa, Cecil, Immortal) + Off.
- `/themes` — cambiar tema (default: omnicoder morado).
- `/help` — ver todos los slash commands disponibles.
- `/routing` — ver rutas por-fase actuales.
- `Ctrl+C` dos veces para salir.

## Auto-actualizaciones

Cuando hay versión nueva, al arrancar `omnicoder` ves un mensaje en
violeta:

```
→ omnicoder 5.0.0-alpha.9 available (current: 5.0.0-alpha.8)
  run:  omnicoder update
```

Corré `omnicoder update` cuando quieras actualizar. Es equivalente a
`npm install -g @nicolas2601/omnicoder@alpha` pero también re-siembra
agents nuevos.

El chequeo se cachea 24h para no spammear el registry. Desactivar con
`$env:OMNICODER_NO_UPDATE_CHECK=1`.

## Si algo falla

1. `omnicoder --version` → pegarme qué sale.
2. Path del binario: `Get-Command omnicoder | Select-Object Source`.
3. Logs: `%USERPROFILE%\.omnicoder\logs\` (si existen).
4. Reinstalar limpio:
   ```powershell
   npm uninstall -g @nicolas2601/omnicoder
   Remove-Item -Recurse -Force "$env:USERPROFILE\.omnicoder"
   Remove-Item -Recurse -Force "$env:APPDATA\opencode\agent"
   Remove-Item -Recurse -Force "$env:APPDATA\opencode\command"
   npm install -g @nicolas2601/omnicoder@alpha
   ```

## Dónde quedó instalado (referencia)

- Binario `omnicoder.cmd` y `omnicoder-routing.cmd`: en tu `npm prefix`
  (corré `npm prefix -g` para ver dónde).
- Assets: `%APPDATA%\opencode\agent\` y `%APPDATA%\opencode\command\`.
- Theme: `%APPDATA%\opencode\theme\omnicoder.json`.
- Config default: `%APPDATA%\opencode\opencode.jsonc`.
- Memoria y presets: `%USERPROFILE%\.omnicoder\`.

---

Cualquier duda → WhatsApp a Nicolás.
