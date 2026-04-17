#!/usr/bin/env bash
# ============================================================
# OmniCoder - Security Guard Hook (PreToolUse: Bash)
# v4.4: 19 patrones peligrosos + 7 patrones secret fusionados en 2
# alternancias grep. Reduce de ~38 fork/execs a 2.
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

# Early-exit rapidisimo: si no es Bash, allow sin jq
case "$INPUT" in
    *'"tool_name":"Bash"'*|*'"tool_name": "Bash"'*) ;;
    *)
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"no-bash"}}\n'
        exit 0 ;;
esac

# v4.4: un solo jq extrae tool_name y command juntos (antes eran 3 jq calls)
read -r TOOL_NAME COMMAND < <(echo "$INPUT" | jq -r '[(.tool_name // ""), (.tool_input.command // "")] | @tsv' 2>/dev/null || echo -e "\t")

if [[ "$TOOL_NAME" == "Bash" ]] && [[ -n "$COMMAND" ]]; then
    # v4.4: fusionar 19 patrones destructivos en una sola alternancia.
    # Un solo grep en vez de 19 echos+greps (ahorra ~36 forks).
    DANGEROUS_RE='rm\s+-r[f ]*\s+/|rm\s+-r[f ]*\s+~|rm\s+-rf\s+\*|rm\s+.*--no-preserve-root|:\(\)\s*\{.*:\|:.*\}|mkfs\.|dd\s+if=/dev/(zero|random)|>\s*/dev/sd[a-z]|chmod\s+[0-7]*7[0-7]*\s+/(etc|usr|var|boot|bin|sbin)|chmod\s+-R\s+777\s+/|curl.*\|\s*(ba)?sh|wget.*\|\s*(ba)?sh|bash\s*<\(curl|bash\s*<\(wget|eval\s.*\$\(|python[23]?\s+-c\s+.*os\.(system|popen|exec)|sudo\s+rm\s+-rf\s+/|mv\s+/\s+/dev/null|ln\s+-sf?\s+/dev/null\s+/(etc|usr|bin)'

    if MATCHED=$(echo "$COMMAND" | grep -oiE "$DANGEROUS_RE" | head -1); then
        if [[ -n "$MATCHED" ]]; then
            jq -n --arg p "$MATCHED" '{
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": ("BLOQUEADO: Comando peligroso detectado. Patron: " + $p)
                }
            }'
            exit 0
        fi
    fi

    # v4.4: fusionar 7 patrones secret en uno
    SECRET_RE='cat.*\.env|echo.*API_KEY|echo.*SECRET|echo.*PASSWORD|echo.*TOKEN|printenv.*KEY|printenv.*SECRET'

    if echo "$COMMAND" | grep -qiE "$SECRET_RE"; then
        jq -n '{
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "BLOQUEADO: Posible exposicion de secrets detectada."
            }
        }'
        exit 0
    fi
fi

# Permitir por defecto (printf en vez de jq -n, ahorra ~5ms)
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Comando seguro"}}\n'
