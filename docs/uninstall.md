# Desinstalar OmniCoder v5

Procedimiento oficial para remover OmniCoder y (opcionalmente) todo lo
que dejó instalado en tu máquina.

---

## Linux / macOS

```bash
cd ~/omnicoder-v5          # o donde tengas el repo clonado
bash scripts/install.sh --uninstall --yes
```

Lo que hace:

1. Borra `/usr/local/bin/omnicoder*` (wrappers).
2. Preserva `~/.omnicoder/` **a menos que** pases `--purge-home`.
3. Preserva `~/.config/opencode/opencode.jsonc` (config del usuario).
4. **No** toca el paquete global `opencode-ai` (usalo solo):
   ```bash
   npm uninstall -g opencode-ai
   ```
5. **No** toca `engram` — se saca con:
   ```bash
   rm -f /usr/local/bin/engram
   ```

### Desinstalación total (purga todo):

```bash
bash scripts/install.sh --uninstall --yes --purge-home
npm uninstall -g opencode-ai
rm -f /usr/local/bin/engram
# opcional: el repo clonado
rm -rf ~/omnicoder-v5
```

---

## Windows

```powershell
cd $env:USERPROFILE\omnicoder-v5
pwsh .\scripts\install-windows.ps1 -Uninstall -Yes
```

Hace lo mismo que el installer Linux inversamente:

1. Remueve `%LOCALAPPDATA%\Programs\omnicoder\bin\omnicoder*`.
2. Saca esa carpeta del **User PATH** vía `[Environment]::SetEnvironmentVariable`.
3. Preserva `%USERPROFILE%\.omnicoder\` salvo que pases `-PurgeHome`.
4. Preserva `%APPDATA%\opencode\opencode.jsonc`.

### Purga total Windows:

```powershell
pwsh .\scripts\install-windows.ps1 -Uninstall -Yes -PurgeHome
npm uninstall -g opencode-ai
Remove-Item -Recurse -Force "$env:APPDATA\opencode" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:USERPROFILE\omnicoder-v5" -ErrorAction SilentlyContinue
```

---

## Qué **NO** se borra nunca por el installer

Para proteger tu trabajo, estos paths nunca se tocan sin un flag explícito:

- `~/.omnicoder/memory/` — tu memoria persistente en Markdown.
- `~/.omnicoder/conversations/` — historial de sesiones.
- Cualquier `.env` o `secrets.json` que haya puesto el usuario.

Si hacés `--purge-home` / `-PurgeHome`, **sí** se borran. Hacé backup antes:

```bash
tar czf ~/omnicoder-last-backup.tar.gz ~/.omnicoder
```

```powershell
Compress-Archive -Path "$env:USERPROFILE\.omnicoder" `
  -DestinationPath "$env:USERPROFILE\omnicoder-last-backup.zip" -Force
```

---

## Validación post-desinstalación

```bash
command -v omnicoder        # debería devolver nada y exit code 1
omnicoder --version 2>&1    # "command not found"
```

```powershell
Get-Command omnicoder -ErrorAction SilentlyContinue
# debería ser $null
```
