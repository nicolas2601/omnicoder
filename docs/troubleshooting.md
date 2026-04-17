# Troubleshooting

## Scroll bug del TUI

**Síntoma**: en Linux/Windows el scroll con mouse hacia arriba no funciona dentro del CLI.

**Causa**: bug conocido del upstream Qwen Code (TUI basada en Ink/React). No es de OmniCoder.

**Workarounds**:

- `Shift+PgUp` / `Shift+PgDn` en vez de scroll con mouse.
- `tmux`: `Ctrl+B` → `[` para entrar en modo scroll.
- Terminales con mejor soporte TUI: **kitty**, **wezterm**, **alacritty**.
- Headless mode: `qwen -p "prompt" > output.txt` para ver todo sin UI.

## Hooks no funcionan en Windows (PowerShell/CMD)

**Síntoma**: `Request timed out waiting for hook-execution-response`.

**Causa**: los hooks son scripts bash. PowerShell y CMD no pueden ejecutarlos.

**Fix**:

1. Instala [Git for Windows](https://git-scm.com/download/win).
2. Desinstala la instalación Windows-native:
   ```powershell
   .\scripts\uninstall-windows.ps1 -Force
   ```
3. Reinstala desde **Git Bash**:
   ```bash
   git clone https://github.com/nicolas2601/omnicoder.git
   cd omnicoder
   chmod +x scripts/install-linux.sh
   ./scripts/install-linux.sh
   ```

## `jq: command not found`

**Síntoma**: hooks fallan silenciosamente, `settings.json` no se parsea.

**Fix**:

```bash
# Linux (Arch)
sudo pacman -S jq

# Linux (Debian/Ubuntu)
sudo apt install jq

# macOS
brew install jq

# Windows (Git Bash)
# Descarga el binario de https://stedolan.github.io/jq/download/ y ponlo en PATH
```

Verifica:

```bash
jq --version
```

## NVIDIA NIM "cloud credits expired"

**Síntoma**: requests a NVIDIA devuelven 401/402 con mensaje de créditos agotados.

**Causa**: el free tier de NIM tiene créditos cloud finitos que caducan.

**Fix**: switch de provider.

```bash
./scripts/switch-provider.sh
# Selecciona Gemini (1500 req/día free) o MiniMax ($10/mes)
```

## 429 rate limit

**Síntoma**: requests fallan con `429 Too Many Requests`.

**Causa**: pasaste el RPM o TPM del provider.

**Fix automático**: `provider-failover.sh` detecta 3+ eventos 429 y emite sugerencia de failover. Sigue la recomendación:

1. `./scripts/switch-provider.sh` a un provider con más throughput.
2. `/turbo on` para reducir paralelismo de hooks.
3. Si estás en Groq, **cámbiate**: su TPM es incompatible con el paralelismo de OmniCoder.

## Tarea muy lenta

**Síntomas**: respuestas tardan 30+s, la sesión se arrastra.

**Opciones por velocidad**:

```bash
# 1. Activar turbo mode (desactiva 17 hooks, mantiene sólo security-guard)
./scripts/turbo-mode.sh on

# 2. Saltar npx skills add (si ya tienes todo local)
export OMNICODER_SKIP_NPX=1

# 3. Usar modelo local (Ollama)
ollama pull qwen2.5-coder:7b
# dentro del CLI: /model → selecciona el local

# 4. Headless mode sin UI
qwen -p "Crea src/server.js con Express" --yolo
```

Tabla de velocidad:

| Config | Latencia | Costo |
|--------|----------|-------|
| API remota + hooks full | Lenta | Varía |
| API remota + turbo | Media | Varía |
| API dedicada + turbo | Rápida | ~$0.01/req |
| Ollama local + turbo | Ultra rápida | Gratis |
| Headless + Ollama | Máxima | Gratis |

## Router ignora skill sugerida

**Síntoma**: el router recomienda `[OBLIGATORIO] skill X` pero el modelo no lo usa.

**Debug**:

```bash
# 1. Revisa el score del skill
cat ~/.omnicoder/memory/skill-stats.json | jq .

# 2. Mira los últimos ignores
cat ~/.omnicoder/memory/ignored-skills.md

# 3. Fuerza re-indexación
~/.omnicoder/scripts/build-skill-index.sh
```

Tras 3+ ignores, `skill-usage-tracker.sh` eleva el score del skill automáticamente (+2). Si sigue sin usarse, revisa que el `description` del `SKILL.md` contiene palabras clave del prompt.

## Subagent reporta listo pero no hizo nada

**Síntoma**: `Task` termina con éxito pero los archivos no cambiaron.

**Fix**: `subagent-verify.sh` debería detectarlo y emitir `[VERIFICACION-FALLIDA]`. Si pasó por alto:

```
/verify-last
```

Verifica mtime, git diff y logs. Si el subagent mintió, re-invoca con instrucciones más específicas.

## Errores 400 del modelo coder

**Síntoma**: `Task` falla con "400 Bad Request" desde el provider.

**Causa**: prompt muy largo (>4000 chars), demasiados code-fences (>6 backticks), o 3+ subagents en paralelo agotando el TPM.

**Fix automático**: `subagent-error-recover.sh` detecta 4 patrones y emite `[SUBAGENT-400-DETECTADO]` con plan:

- Acortar prompt.
- Quitar code-fences.
- Usar Edit directo en vez de Task.
- Ejecutar secuencial en vez de paralelo con 3+ subagents.

Contador en `~/.omnicoder/logs/subagent-400-errors.log`. Tras 3+ errores sugiere `turbo-mode on` o cambio de modelo.

## "Streaming request timeout after 45s"

**Causa**: timeout default del CLI base.

**Fix**: asegúrate de tener `contentGenerator.timeout: 180000` en `~/.qwen/settings.json`:

```json
{
  "contentGenerator": {
    "timeout": 180000
  }
}
```

El instalador de OmniCoder lo escribe automáticamente; sólo aparece si editaste el archivo a mano.

## Desinstalar limpio

```bash
# Linux / macOS / Git Bash
./scripts/uninstall-linux.sh

# Windows PowerShell
.\scripts\uninstall-windows.ps1 -Force

# Windows CMD
scripts\uninstall-windows.bat
```

Elimina `~/.omnicoder/` y limpia la sección `hooks` de `settings.json`. NO toca el CLI base ni el resto de `settings.json`.
