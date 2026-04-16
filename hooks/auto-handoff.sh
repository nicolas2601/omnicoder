#!/usr/bin/env bash
# ============================================================
# OmniCoder - Auto Handoff (Stop)
# Genera recordatorio de handoff al finalizar sesiones productivas
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Contar operaciones de la sesion actual
LOG_FILE="$HOME/.omnicoder/logs/operations.log"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

if [[ -f "$LOG_FILE" ]] && [[ -n "$SESSION_ID" ]]; then
    OP_COUNT=$(grep -c "$SESSION_ID" "$LOG_FILE" 2>/dev/null) || OP_COUNT=0

    # Solo sugerir handoff si hubo actividad significativa (5+ operaciones)
    if [[ "$OP_COUNT" -gt 5 ]]; then
        jq -n '{
            "hookSpecificOutput": {
                "hookEventName": "Stop",
                "additionalContext": "Sesion productiva detectada. Considera crear un handoff: /handoff"
            }
        }'
        exit 0
    fi
fi

echo '{}'
