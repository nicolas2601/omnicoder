#!/usr/bin/env bash
# ============================================================
# OmniCoder - Causal Learner (PostToolUse)
# Detecta pares (X falla -> Y funciona) y los guarda como
# causal edges: "si X falla, probar Y".
#
# Mantiene un buffer de 2 tools consecutivos. Si tool[N-1] falló
# y tool[N] tuvo éxito con signature similar -> causal edge.
# ============================================================
set -euo pipefail

INPUT=$(cat)
MEM_DIR="$HOME/.omnicoder/memory"
CACHE_DIR="$HOME/.omnicoder/.cache"
mkdir -p "$MEM_DIR" "$CACHE_DIR"

BUFFER="$CACHE_DIR/tool-buffer.json"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0' 2>/dev/null || echo 0)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null | head -c 200)

[[ "$TOOL_NAME" != "Bash" ]] && exit 0

CMD=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null | head -c 200)
[[ -z "$CMD" ]] && exit 0

# Categorizar comando (primera palabra significativa)
CMD_HEAD=$(echo "$CMD" | awk '{print $1}' | xargs basename 2>/dev/null || echo "")
# Si hay npm/yarn/pnpm run X -> tomar X
if [[ "$CMD_HEAD" =~ ^(npm|yarn|pnpm|npx)$ ]]; then
    CMD_HEAD="$CMD_HEAD $(echo "$CMD" | awk '{print $2, $3}')"
fi

STATUS="ok"
[[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]] && STATUS="fail"
echo "$RESPONSE" | grep -qiE '(command not found|no such file|permission denied|fatal:|error:)' && STATUS="fail"

NOW=$(date +%s)

# Leer buffer previo
PREV_CMD=""
PREV_STATUS=""
PREV_TS=0
if [[ -f "$BUFFER" ]]; then
    PREV_CMD=$(jq -r '.cmd // ""' "$BUFFER" 2>/dev/null)
    PREV_STATUS=$(jq -r '.status // ""' "$BUFFER" 2>/dev/null)
    PREV_TS=$(jq -r '.ts // 0' "$BUFFER" 2>/dev/null)
fi

# Guardar actual al buffer para próxima iteración
jq -n --arg cmd "$CMD_HEAD" --arg status "$STATUS" --arg full "$CMD" --argjson ts "$NOW" \
    '{cmd:$cmd, status:$status, full:$full, ts:$ts}' > "$BUFFER"

# Detección de causal edge:
#  prev falló, actual ok, mismo "tema" (comparten primera palabra), gap < 120s
if [[ "$PREV_STATUS" == "fail" ]] && [[ "$STATUS" == "ok" ]]; then
    GAP=$((NOW - PREV_TS))
    if [[ "$GAP" -gt 0 ]] && [[ "$GAP" -lt 120 ]]; then
        PREV_FIRST=$(echo "$PREV_CMD" | awk '{print $1}')
        CURR_FIRST=$(echo "$CMD_HEAD" | awk '{print $1}')

        if [[ "$PREV_FIRST" == "$CURR_FIRST" ]] || [[ -n "$PREV_FIRST" && "$CMD" == *"$PREV_FIRST"* ]]; then
            CAUSAL_FILE="$MEM_DIR/causal-edges.md"
            if [[ ! -f "$CAUSAL_FILE" ]]; then
                cat > "$CAUSAL_FILE" <<'EOF'
# Causal Edges (Si X falla → probar Y)

Aprendizaje automático de recuperaciones exitosas.

---
EOF
            fi

            SIG=$(echo "${PREV_CMD}${CMD_HEAD}" | md5sum | cut -d' ' -f1)
            if ! grep -q "sig:$SIG" "$CAUSAL_FILE" 2>/dev/null; then
                echo "- Si falla \`$PREV_CMD\` → probar \`$CMD_HEAD\` ($(date -Iseconds)) sig:$SIG" >> "$CAUSAL_FILE"
            fi
        fi
    fi
fi

exit 0
