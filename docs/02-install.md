# 02 · Instalación detallada

## Opción A — clonar el repo (recomendada)

```bash
git clone https://github.com/nicolas2601/omnicoder ~/omnicoder-v5
cd ~/omnicoder-v5
bash scripts/install.sh --yes
```

```powershell
git clone https://github.com/nicolas2601/omnicoder $env:USERPROFILE\omnicoder-v5
cd $env:USERPROFILE\omnicoder-v5
pwsh .\scripts\install-windows.ps1 -Yes
```

## Opción B — one-liner curlable (sin repo local)

```bash
curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/install.sh | bash -s -- --yes
```

```powershell
iwr -useb https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/install-windows.ps1 | iex
```

> Si vas a contribuir, preferí la Opción A — necesitás el repo para
> correr tests, benchmarks y sincronizar upstream.

---

## Flags del installer (POSIX)

```
--yes            no preguntar confirmaciones (modo CI)
--prefix DIR     prefix de instalación (default /usr/local)
--no-sudo        no escalar a sudo; falla si no hay permisos
--uninstall      desinstalar en vez de instalar
--purge-home     junto con --uninstall borra ~/.omnicoder/ también
```

Overrides via environment:

```bash
PREFIX=$HOME/.local bash scripts/install.sh --yes --no-sudo   # instalación user-local
ENGRAM_SKIP=1 bash scripts/install.sh --yes                   # saltar Engram
ENGRAM_SHA256_LINUX_X64="abcd…" bash scripts/install.sh --yes # pinnear checksum custom
```

## Flags del installer (Windows PS1)

```
-Yes                    no preguntar confirmaciones
-InstallDir <path>      override del destino (default %LOCALAPPDATA%\Programs\omnicoder\bin)
-Uninstall              desinstalar
-PurgeHome              junto con -Uninstall borra %USERPROFILE%\.omnicoder\ también
-SkipEngramVerify       saltar verificación SHA-256 de Engram (dev-only)
-EngramSha256 <hex>     pinnear checksum custom
```

---

## Qué instala

| Paso | Artefacto | Dónde |
|---|---|---|
| 1 | `opencode` global npm | `$(npm root -g)/opencode-ai` |
| 2 | `engram` binary (SHA-256 verificado, SEC-05) | `$PREFIX/bin/engram` · `$InstallDir\engram.exe` |
| 3 | Wrappers `omnicoder*` | `$PREFIX/bin/` · `$InstallDir\` |
| 4 | Skills + agents (solo si faltan) | `~/.omnicoder/{skills,agents}/` |
| 5 | `opencode.jsonc` default (solo si no existe) | `~/.config/opencode/` · `%APPDATA%\opencode\` |
| 6 | PATH patch (Windows únicamente) | User PATH vía `[Environment]::SetEnvironmentVariable` |

El paso 4 usa **copy-if-missing**: nunca sobrescribe archivos del
usuario. Si querés forzar reseteo de skills/agents, borralos antes:

```bash
rm -rf ~/.omnicoder/skills ~/.omnicoder/agents
bash scripts/install.sh --yes
```

---

## Ubicaciones estándar

| | Linux/macOS | Windows |
|---|---|---|
| Binary user | `/usr/local/bin/omnicoder` | `%LOCALAPPDATA%\Programs\omnicoder\bin\omnicoder.cmd` |
| Home del runtime | `~/.omnicoder/` | `%USERPROFILE%\.omnicoder\` |
| Config Opencode | `~/.config/opencode/opencode.jsonc` | `%APPDATA%\opencode\opencode.jsonc` |
| Memory del usuario | `~/.omnicoder/memory/*.md` | `%USERPROFILE%\.omnicoder\memory\*.md` |
| Logs JSONL | `~/.omnicoder/logs/` | `%USERPROFILE%\.omnicoder\logs\` |

---

## Actualización

```bash
cd ~/omnicoder-v5
git pull origin main
bash scripts/install.sh --yes   # idempotente; re-verifica Engram SHA-256
```

```powershell
cd $env:USERPROFILE\omnicoder-v5
git pull origin main
pwsh .\scripts\install-windows.ps1 -Yes
```

---

## Desinstalación

Ver [`uninstall.md`](uninstall.md).
