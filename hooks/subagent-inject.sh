#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Subagent Contract Injector (PreToolUse matcher=Task)
# v3.5: agrega reglas anti-400 ("function.arguments must be JSON")
#       para el modelo gratuito qwen3-coder.
#
# Cuando el agente principal invoca Task (subagent), inyecta un
# additionalContext que exige:
#   1. Formato de evidencia al terminar (<verification>)
#   2. Reglas de construccion de prompt para evitar el 400 del coder model
# ============================================================
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" != "Task" ]] && { echo '{}'; exit 0; }

# --------------------------------------------------------
# Deteccion: prompt demasiado grande o con caracteres peligrosos
# --------------------------------------------------------
SUB_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // .tool_input.description // ""' 2>/dev/null || echo "")
PROMPT_LEN=${#SUB_PROMPT}
WARN=""

if [[ "$PROMPT_LEN" -gt 4000 ]]; then
    WARN="⚠️ [ANTI-400] Prompt del subagent mide ${PROMPT_LEN} chars (>4000). En qwen3-coder gratis esto CAUSA error 400 'function.arguments must be JSON'. Acorta a <3000 chars o divide en varios subagents secuenciales.
"
fi

# Backticks + comillas sin escapar dentro del prompt rompen el JSON del coder model
BACKTICK_COUNT=$(echo "$SUB_PROMPT" | tr -cd '`' | wc -c)
if [[ "$BACKTICK_COUNT" -gt 6 ]]; then
    WARN="${WARN}⚠️ [ANTI-400] Prompt contiene ${BACKTICK_COUNT} backticks. Code fences embebidos rompen function.arguments en qwen3-coder. Reemplaza bloques \`\`\`...\`\`\` con referencias 'ver archivo X.ts lineas N-M'.
"
fi

CTX="📋 CONTRATO OBLIGATORIO DE VERIFICACION (para el subagent invocado):

Al terminar tu trabajo, el subagent DEBE incluir al final de su respuesta un bloque como este:

<verification>
files: [ruta/archivo1.ts, ruta/archivo2.md]
commands: [npm test, git diff]
tests: true
summary: resumen breve del trabajo hecho
</verification>

Reglas de evidencia:
- 'files' SOLO archivos realmente modificados (el hook verificara mtime)
- 'commands' SOLO comandos que realmente se ejecutaron
- 'tests: true' SOLO si se corrieron y hay output visible con PASS/OK
- Si no hubo trabajo, usar: files:[], commands:[], tests:false

═══════════════════════════════════════════════════════
🔒 REGLAS ANTI-400 (qwen3-coder gratis — modelo estricto con JSON):
═══════════════════════════════════════════════════════

El endpoint DashScope rechaza con 400 'function.arguments must be JSON' si el
prompt enviado al subagent contiene:

1. Mas de 4000 caracteres → ACORTA o divide en 2-3 subagents secuenciales.
2. Bloques de codigo extensos con \`\`\`...\`\`\` dentro del prompt →
   Referencia archivos (Read tool) en vez de pegar codigo.
3. Comillas dobles sin escapar en strings largos → usa comillas simples.
4. Mas de 3 subagents en paralelo con prompts grandes → spawn SECUENCIAL.

Si ves error 'InternalError.Algo.InvalidParameter: function.arguments must
be in JSON format': el hook subagent-error-recover.sh te dira exactamente
que subagent acortar. Re-invoca ese subagent con prompt <2500 chars.

${WARN}Sin cumplir estas reglas + sin el bloque <verification>, el resultado sera
RECHAZADO automaticamente por los hooks de post-procesamiento."

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$ctx}}'
