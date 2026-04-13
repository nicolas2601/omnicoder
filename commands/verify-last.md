---
description: Verifica manualmente el output del ultimo subagent invocado
---

# /verify-last

Comando manual para auditar la ultima invocacion de subagent cuando dudas de su reporte.

## Proceso

1. Lee `~/.qwen/logs/subagent-verify.log` (ultimas 5 lineas) para ver el estado.
2. Lee `~/.qwen/logs/operations.log` (ultimas 50 lineas) para ver tools ejecutados en la sesion actual.
3. Para cada archivo que el subagent dijo modificar:
   - `git diff --stat HEAD` en el cwd del proyecto
   - `stat -c '%y %n' <archivo>` para verificar mtime
   - `Read` del archivo para verificar contenido real vs lo declarado
4. Si el subagent dijo tests pasaron, corre el comando de test real y compara.
5. Reporte final al usuario con formato:
   ```
   VERIFICACION DEL ULTIMO SUBAGENT
   - Archivos declarados: N | Existen: M | Modificados recientemente: K
   - Tests declarados: pass/fail | Tests reales: pass/fail
   - Veredicto: OK | SOSPECHOSO | MENTIRA
   ```

## Cuando usar
- Despues de un subagent que reporta "listo" pero no ves cambios visibles.
- Antes de hacer `/ship` o commit si hay dudas.
- Cuando el hook subagent-verify.sh ya marco [VERIFICACION-FALLIDA] y quieres detalle.

## Fallback
Si no hay logs (sesion nueva), pide al usuario que repita la invocacion con contrato explicito.
