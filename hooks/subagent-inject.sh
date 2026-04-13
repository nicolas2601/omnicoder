#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Subagent Contract Injector (PreToolUse matcher=Task)
#
# Cuando el agente principal invoca Task (subagent), inyecta un
# additionalContext que exige al subagent terminar su respuesta
# con un bloque <verification> con evidencia estructurada.
#
# El hook subagent-verify.sh (PostToolUse) valida esa evidencia.
# ============================================================
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" != "Task" ]] && { echo '{}'; exit 0; }

CTX="📋 CONTRATO OBLIGATORIO DE VERIFICACION (para el subagent invocado):

Al terminar tu trabajo, el subagent DEBE incluir al final de su respuesta un bloque como este:

<verification>
files: [ruta/archivo1.ts, ruta/archivo2.md]
commands: [npm test, git diff]
tests: true
summary: resumen breve del trabajo hecho
</verification>

Reglas:
- 'files' SOLO archivos realmente modificados (el hook verificara mtime)
- 'commands' SOLO comandos que realmente se ejecutaron
- 'tests: true' SOLO si se corrieron y hay output visible con PASS/OK
- Si no hubo trabajo, usar: files:[], commands:[], tests:false

Sin este bloque o con datos inventados, el resultado sera RECHAZADO automaticamente por el verificador post-hook."

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$ctx}}'
