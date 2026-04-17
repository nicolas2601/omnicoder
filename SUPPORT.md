# Support — Guía de instalación, desinstalación y troubleshooting

Esta guía cubre **todo** lo que necesitas para instalar, usar y desinstalar OmniCoder en Linux, macOS y Windows. Si tu problema no está aquí, abre un [issue](https://github.com/nicolas2601/omnicoder/issues/new/choose).

---

## Índice

- [Requisitos previos](#requisitos-previos)
- [Instalación en Linux / macOS](#instalación-en-linux--macos)
- [Instalación en Windows](#instalación-en-windows)
- [Primer arranque](#primer-arranque)
- [Configurar provider (API key)](#configurar-provider-api-key)
- [Actualizar OmniCoder](#actualizar-omnicoder)
- [Desinstalación completa](#desinstalación-completa)
- [Troubleshooting](#troubleshooting)
- [Obtener ayuda](#obtener-ayuda)

---

## Requisitos previos

| Dependencia | Versión | Instalación |
|---|---|---|
| **Node.js** | ≥ 20.0 | `winget install OpenJS.NodeJS.LTS` (Win) · `brew install node@20` (macOS) · `sudo apt install nodejs` (Debian/Ubuntu) |
| **git** | cualquiera | `winget install Git.Git` · `brew install git` · `sudo apt install git` |
| **bash** | ≥ 4.0 | nativo en Linux/macOS · Git Bash incluido con Git for Windows |
| **jq** | cualquiera | `brew install jq` · `sudo apt install jq` · (Windows: auto-descargado por el instalador) |

Para Windows es **muy recomendable** instalar [Git for Windows](https://git-scm.com/download/win), que trae Git Bash incluido (necesario para que los hooks de OmniCoder funcionen).

---

## Instalación en Linux / macOS

### Método 1 — One-liner (recomendado)

```bash
git clone https://github.com/nicolas2601/omnicoder.git && \
  cd omnicoder && \
  chmod +x scripts/install-linux.sh && \
  ./scripts/install-linux.sh
```

El instalador:

1. Verifica prerequisitos (Node ≥ 20, git, bash ≥ 4, jq).
2. Instala `@qwen-code/qwen-code` global si no está.
3. Copia los **168 agentes**, **193 skills**, **20 hooks** y **21 comandos** a `~/.omnicoder/`.
4. Sincroniza `~/.omnicoder/OMNICODER.md` → `~/.qwen/QWEN.md` (system prompt optimizado).
5. Añade `allowedCommands` a `~/.qwen/settings.json` para que los slash commands no pidan permiso cada vez.
6. Crea el comando global `omnicoder` con un symlink en `~/.local/bin/`.
7. Te pregunta si quieres configurar un provider ahora (NVIDIA NIM / Gemini / MiniMax / DeepSeek / OpenRouter / Ollama).

### Método 2 — Instalación manual paso a paso

```bash
# 1. Clonar el repo
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder

# 2. Instalar qwen CLI (base que OmniCoder extiende)
npm install -g @qwen-code/qwen-code@latest

# 3. Correr el instalador con flags opcionales
./scripts/install-linux.sh --force         # sobrescribir sin preguntar
./scripts/install-linux.sh --skip-cli      # no reinstalar qwen CLI
./scripts/install-linux.sh --doctor        # solo diagnóstico, no instala
```

### Método 3 — Solo diagnóstico (comprobar instalación existente)

```bash
./scripts/install-linux.sh --doctor
```

---

## Instalación en Windows

Tienes tres opciones. **La más recomendada es instalar Git for Windows primero** (incluye Git Bash que necesitan los hooks).

### Opción A — Desde CMD nativo

Abre **cmd.exe** (no PowerShell) y ejecuta:

```cmd
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder
scripts\install-windows.bat
```

Flags disponibles:

```cmd
scripts\install-windows.bat /SKIP_CLI    :: no reinstalar qwen CLI
scripts\install-windows.bat /FORCE       :: sobrescribir todo sin preguntar
scripts\install-windows.bat /DOCTOR      :: solo diagnóstico
scripts\install-windows.bat /HELP        :: ayuda
```

El `.bat` también acepta estilo Unix: `--skip-cli`, `--force`, `--doctor`, `--help`.

### Opción B — Desde PowerShell

Abre **PowerShell 5.1+** o **PowerShell 7+**:

```powershell
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder
.\scripts\install-windows.ps1
```

Flags:

```powershell
.\scripts\install-windows.ps1 -SkipCli    # no reinstalar qwen CLI
.\scripts\install-windows.ps1 -Force      # sobrescribir sin preguntar
.\scripts\install-windows.ps1 -Doctor     # solo diagnóstico
.\scripts\install-windows.ps1 -Update     # alias de -Force
```

Si PowerShell bloquea el script con "execution policy", ejecuta **una vez**:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Opción C — Desde Git Bash

Abre **Git Bash** (no MINGW ni MSYS2) e instala como en Linux:

```bash
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder
./scripts/install-linux.sh
```

### Qué hace el instalador de Windows

1. Detecta Node ≥ 20, git, bash (Git Bash), jq.
2. Si `jq` falta, lo descarga automáticamente a `%USERPROFILE%\.omnicoder\bin\jq.exe` (con `curl`, viene con Windows 10+).
3. Instala `@qwen-code/qwen-code` global si no está.
4. Copia la estructura a `%USERPROFILE%\.omnicoder\`.
5. Añade `%USERPROFILE%\.omnicoder\` al **PATH de usuario** (usando PowerShell `SetEnvironmentVariable`, no `setx` que trunca a 1024 chars).
6. Limpia **caches OAuth residuales** (`oauth_creds.json`, `access_token`, `refresh_token`, `.qwen_session`, `auth.json`) que causaban que qwen pidiera auth aunque hubiese API key configurada.
7. Sincroniza `QWEN.md` (system prompt) + `allowedCommands` en settings.

Después de instalar, **cierra y reabre la terminal** para que el PATH tenga efecto.

---

## Primer arranque

```bash
omnicoder
```

O en Windows desde CMD: `omnicoder.cmd` · desde PowerShell: `omnicoder.ps1`.

Verás el banner, el provider activo, los contadores (168 agentes · 193 skills · 20 hooks · 21 comandos) y el prompt de qwen. Si no tienes `.env` configurado, ejecuta `./scripts/setup-provider.sh` (Linux/macOS) o `.\scripts\setup-provider.ps1` (Windows).

### Slash commands útiles

| Comando | Qué hace |
|---|---|
| `/personality set omni-man` | Activa alter-ego viltrumita (Nolan Grayson) |
| `/personality list` | Ver todas las personalidades disponibles |
| `/review` | Code review del diff actual |
| `/ship` | Tests + lint + commit + push |
| `/audit` | Auditoría completa (seguridad, perf, código) |
| `/handoff` | Guarda progreso para retomar después |

---

## Configurar provider (API key)

OmniCoder soporta **6+ providers** drop-in:

| Provider | Plan | Endpoint |
|---|---|---|
| **NVIDIA NIM** | FREE (40 RPM, créditos finitos) | `https://integrate.api.nvidia.com/v1` |
| **Google Gemini** | FREE 1500 req/día | `https://generativelanguage.googleapis.com/v1beta/openai/` |
| **MiniMax** | $10/mes flat | `https://api.minimax.io/v1` |
| **DeepSeek** | Pay-as-you-go barato (cache 90% off) | `https://api.deepseek.com/v1` |
| **OpenRouter** | Agregador, FREE + pagos | `https://openrouter.ai/api/v1` |
| **Ollama** | Local, gratis | `http://localhost:11434/v1` |

Setup interactivo:

```bash
./scripts/setup-provider.sh                 # Linux/macOS
.\scripts\setup-provider.ps1                # Windows
```

Cambio rápido entre providers:

```bash
./scripts/switch-provider.sh gemini
./scripts/switch-provider.sh nvidia
./scripts/switch-provider.sh minimax
```

Detalles en [`docs/providers.md`](./docs/providers.md).

---

## Actualizar OmniCoder

```bash
cd omnicoder
git pull
./scripts/install-linux.sh --force    # Linux/macOS
scripts\install-windows.bat /FORCE    # Windows
```

Antes de sobrescribir, el instalador **respalda automáticamente** `~/.omnicoder/settings.json` y `memory/` en `~/.omnicoder/.backups/`. Para gestionar backups:

```bash
./scripts/backup.sh --label "antes-de-experimento"
./scripts/restore.sh list
./scripts/restore.sh restore 1
./scripts/restore.sh pin 1           # proteger de auto-prune
```

---

## Desinstalación completa

Los uninstallers **eliminan todo**: `~/.omnicoder/` entero, `~/.qwen/` (settings + OAuth caches + QWEN.md + commands), el paquete `@qwen-code/qwen-code` global, entradas de PATH y la variable `OMNICODER_HOME`.

### Linux / macOS

```bash
./scripts/uninstall-linux.sh                    # con confirmación
./scripts/uninstall-linux.sh --force            # sin preguntar
./scripts/uninstall-linux.sh --keep-memory      # conserva aprendizajes en ~/.omnicoder/memory/
./scripts/uninstall-linux.sh --keep-qwen        # no desinstala qwen CLI
./scripts/uninstall-linux.sh --dry-run          # muestra qué haría, no borra
```

### Windows (PowerShell)

```powershell
.\scripts\uninstall-windows.ps1
.\scripts\uninstall-windows.ps1 -Force
.\scripts\uninstall-windows.ps1 -KeepMemory
.\scripts\uninstall-windows.ps1 -KeepQwen
.\scripts\uninstall-windows.ps1 -DryRun
```

### Windows (CMD)

```cmd
scripts\uninstall-windows.bat          :: ejecuta el .ps1 con ExecutionPolicy Bypass
```

Con `--keep-memory` / `-KeepMemory`, tu memoria se respalda a `~/.omnicoder-memory-backup-YYYYMMDD-HHMMSS.tar.gz` (Linux) o `.zip` (Windows) antes de borrar el resto.

**Después de desinstalar, reinicia la terminal** para que el PATH quede limpio.

---

## Troubleshooting

### El comando `omnicoder` no funciona después de instalar (Windows)

**Causa**: el PATH se añade al scope de usuario, pero tu terminal actual todavía usa el PATH antiguo.

**Solución**: cierra y reabre la terminal. Si aún no funciona:

```powershell
# Verifica que el PATH de usuario contiene ~/.omnicoder
[Environment]::GetEnvironmentVariable('Path', 'User')

# Si falta, añádelo
$omni = Join-Path $env:USERPROFILE '.omnicoder'
$u = [Environment]::GetEnvironmentVariable('Path','User')
[Environment]::SetEnvironmentVariable('Path', "$u;$omni", 'User')
```

### qwen pide auth OAuth aunque tengo API key configurada

**Causa**: caches residuales de OAuth en `~/.qwen/` de instalaciones previas.

**Solución**: los wrappers `omnicoder.cmd` / `.bat` / `.ps1` de v4.3.2+ limpian automáticamente estos archivos al detectar `OPENAI_API_KEY`. Si usaste una versión vieja, elimínalos manual:

```bash
# Linux/macOS
rm -f ~/.qwen/oauth_creds.json ~/.qwen/access_token ~/.qwen/refresh_token ~/.qwen/.qwen_session ~/.qwen/auth.json

# Windows (CMD)
del /q %USERPROFILE%\.qwen\oauth_creds.json
del /q %USERPROFILE%\.qwen\access_token
del /q %USERPROFILE%\.qwen\refresh_token
del /q %USERPROFILE%\.qwen\.qwen_session
del /q %USERPROFILE%\.qwen\auth.json
```

O reinstala OmniCoder con `--force` / `/FORCE` y se limpiarán automáticamente.

### Los hooks se cuelgan en Windows (PowerShell)

**Causa**: `bash` no está en PATH (los hooks son scripts `.sh` que requieren Git Bash).

**Solución**: instala [Git for Windows](https://git-scm.com/download/win). Durante la instalación elige la opción **"Git from the command line and also from 3rd-party software"**.

Verifica:

```cmd
where bash
:: Debería mostrar: C:\Program Files\Git\bin\bash.EXE
```

### `jq: command not found` en los hooks

**Causa**: `jq` no está en PATH.

**Solución Linux/macOS**: `sudo apt install jq` · `brew install jq`.

**Solución Windows**: el instalador lo descarga automáticamente a `%USERPROFILE%\.omnicoder\bin\jq.exe`. Verifica que ese directorio esté en el PATH. Si no, instálalo manual desde [github.com/jqlang/jq/releases](https://github.com/jqlang/jq/releases).

### NVIDIA NIM devuelve "Cloud credits expired"

**Causa**: el tier FREE de NVIDIA NIM tiene créditos limitados (1000 iniciales, 5000 con email empresarial). Una vez agotados, el key sigue válido pero las requests fallan.

**Solución**: cambia a otro provider:

```bash
./scripts/switch-provider.sh gemini       # Google Gemini (FREE 1500 req/día)
./scripts/switch-provider.sh minimax      # MiniMax (pagado, $10/mes)
./scripts/switch-provider.sh deepseek     # DeepSeek (pagado barato)
```

### Error 429 (rate limit)

El hook `provider-failover` (integrado en el dispatcher) detecta automáticamente 429/503/timeouts y sugiere cambiar de provider. Si te pasa seguido, considera cambiar a un plan de pago.

### OmniCoder es lento en tareas simples

**Causa**: los learners/memoria están activos aunque la tarea sea trivial.

**Soluciones**:

1. **Turbo mode** (desactiva hooks no críticos):
   ```bash
   ./scripts/turbo-mode.sh on          # solo security-guard queda
   ./scripts/turbo-mode.sh off         # volver al modo normal
   ```

2. **Skip de npx skills find** (en entornos lentos o offline):
   ```bash
   echo 'export OMNICODER_SKIP_NPX=1' >> ~/.omnicoder/.env
   ```

3. **Headless mode** (sin TUI):
   ```bash
   omnicoder -p "tu prompt aquí" --yolo
   ```

### El router no sugiere la skill correcta

**Diagnóstico**:

```bash
cat ~/.omnicoder/memory/skill-stats.json     # skills usados/ignorados
/skills-stats                                # dentro de OmniCoder
```

Si un skill se ignora 3+ veces, el router lo eleva automáticamente a `[OBLIGATORIO]` en futuros prompts.

### `/personality` no reconoce el comando

**Causa** (resuelto en v4.3.2): Qwen CLI lee commands de `~/.qwen/commands/`, no de `~/.omnicoder/commands/`.

**Solución**: reinstala con `--force` o copia manualmente:

```bash
cp ~/.omnicoder/commands/personality.md ~/.qwen/commands/
```

### TUI se ve roto o el scroll no funciona

**Causa**: bug conocido en la versión upstream de Qwen Code CLI (`@qwen-code/qwen-code`).

**Solución**: reporta en el [repo upstream](https://github.com/QwenLM/qwen-code/issues). Como workaround, usa `omnicoder -p "prompt"` para modo headless.

### Los agentes/skills/hooks no se cargan

**Diagnóstico**:

```bash
./scripts/install-linux.sh --doctor
```

El doctor verifica que existan todos los archivos en `~/.omnicoder/` y que `settings.json` esté bien.

### Perdí mi memoria después de un update

**Causa**: desinstalaste sin `--keep-memory`, o el backup automático falló.

**Solución**: busca el backup automático pre-install en `~/.omnicoder/.backups/`:

```bash
./scripts/restore.sh list
./scripts/restore.sh restore 1
```

Si no hay backups, la memoria se perdió. Para futuras actualizaciones usa siempre `--keep-memory`.

---

## Obtener ayuda

- **Issues**: [github.com/nicolas2601/omnicoder/issues](https://github.com/nicolas2601/omnicoder/issues) — usa los templates de bug-report o feature-request.
- **Discusiones**: [github.com/nicolas2601/omnicoder/discussions](https://github.com/nicolas2601/omnicoder/discussions).
- **Documentación detallada**: [`docs/`](./docs/) — 8 archivos temáticos (getting-started, architecture, hooks, agents, skills, commands, providers, troubleshooting).
- **Seguridad**: reporta vulnerabilidades por email privado a `agenciacreativalab@gmail.com` (ver [SECURITY.md](./SECURITY.md)).
- **Contribuir**: lee [CONTRIBUTING.md](./CONTRIBUTING.md).

---

*Última actualización: v4.3.3 · OmniCoder es MIT · Basado en [Qwen Code CLI](https://github.com/QwenLM/qwen-code) (Apache 2.0).*
