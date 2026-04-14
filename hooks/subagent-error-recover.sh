#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Subagent Error Recovery (PostToolUse matcher=Task)
# v3.5: detecta el error 400 "function.arguments must be JSON" del
#       modelo gratuito qwen3-coder y emite instrucciones de retry
#       acortando el prompt, en vez de dejar que el agente principal
#       reporte falso exito.
#
# Errores tipicos del coder model gratis:
#   - InternalError.Algo.InvalidParameter: The "function.arguments"
#     parameter of the code model must be in JSON format.
#   - 400 sobre tool_calls malformados
#   - timeout por prompt muy grande
#
# Cuando los detecta, aprende (error-learner.sh) y pide retry controlado.
# ============================================================
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" != "Task" ]] && { echo '{}'; exit 0; }

TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_response // .tool_output // .output // ""' 2>/dev/null || echo "")
SUB_DESC=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null || echo "unknown")
SUB_AGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // .tool_input.agent // ""' 2>/dev/null || echo "")
SUB_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
PROMPT_LEN=${#SUB_PROMPT}
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

LOG_DIR="$HOME/.qwen/logs"
mkdir -p "$LOG_DIR"
ERR_LOG="$LOG_DIR/subagent-400-errors.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --------------------------------------------------------
# Patrones de error del modelo coder gratuito
# --------------------------------------------------------
DETECTED=""
if echo "$TOOL_OUTPUT" | grep -qiE 'function\.arguments.*must be.*JSON'; then
    DETECTED="ARGS_NOT_JSON"
elif echo "$TOOL_OUTPUT" | grep -qiE 'InternalError\.Algo\.InvalidParameter'; then
    DETECTED="INVALID_PARAM"
elif echo "$TOOL_OUTPUT" | grep -qiE 'Failed to run subagent.*400'; then
    DETECTED="HTTP_400"
elif echo "$TOOL_OUTPUT" | grep -qiE 'tool_calls?.*malformed|invalid tool_call'; then
    DETECTED="BAD_TOOL_CALL"
fi

if [[ -z "$DETECTED" ]]; then
    echo '{}'
    exit 0
fi

# --------------------------------------------------------
# Log estructurado para error-learner.sh y retrospectiva
# --------------------------------------------------------
echo "$TIMESTAMP|$SESSION_ID|$DETECTED|agent=$SUB_AGENT|desc=$SUB_DESC|prompt_len=$PROMPT_LEN" >> "$ERR_LOG"

# Umbral: si >3 errores del mismo tipo en 24h, sugiere turbo-mode
RECENT_COUNT=$(grep "|$DETECTED|" "$ERR_LOG" 2>/dev/null | tail -20 | wc -l || echo 0)

# --------------------------------------------------------
# Plan de recuperacion
# --------------------------------------------------------
PLAN="1. Re-invoca el subagent '$SUB_AGENT' con prompt <2500 chars (actual: ${PROMPT_LEN}).
2. Quita TODO bloque \`\`\`...\`\`\` del prompt. En su lugar: 'lee archivo X y aplica Y'.
3. Si seguia fallando, usa Edit/Write directamente sin subagent (nivel 1 del arbol de complejidad).
4. Si necesitas paralelo con 3+ subagents, haz SECUENCIAL: primero el critico, luego el resto."

if [[ "$RECENT_COUNT" -ge 3 ]]; then
    PLAN="${PLAN}
5. ⚠️ Detectados ${RECENT_COUNT} errores '$DETECTED' recientes. Considera:
   - Activar turbo-mode (scripts/turbo-mode.sh on) para desactivar hooks pesados
   - Usar qwen-plus o qwen3-max en vez de qwen3-coder para orquestacion
   - Revisar ~/.qwen/logs/subagent-400-errors.log"
fi

CTX="🚨 [SUBAGENT-400-DETECTADO] Tipo: $DETECTED

El subagent '$SUB_AGENT' (${PROMPT_LEN} chars) fallo con un error del modelo
coder gratuito. Esto NO es bug de Qwen Con Poderes — es limitacion conocida
del endpoint DashScope con qwen3-coder cuando recibe tool_calls anidados
largos o mal formados.

NO reportes al usuario 'listo'. Plan de recuperacion OBLIGATORIO:

$PLAN

Log detallado: ~/.qwen/logs/subagent-400-errors.log"

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
