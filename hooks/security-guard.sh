#!/usr/bin/env bash
# ============================================================
# OmniCoder - Security Guard Hook (PreToolUse: Bash)
# Bloquea comandos peligrosos y protege secrets
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')

if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

    # Bloquear comandos destructivos
    DANGEROUS_PATTERNS=(
        'rm\s+-r[f ]*\s+/'
        'rm\s+-r[f ]*\s+~'
        'rm\s+-rf\s+\*'
        'rm\s+.*--no-preserve-root'
        ':\(\)\s*\{.*:\|:.*\}'
        'mkfs\.'
        'dd\s+if=/dev/(zero|random)'
        '>\s*/dev/sd[a-z]'
        'chmod\s+[0-7]*7[0-7]*\s+/(etc|usr|var|boot|bin|sbin)'
        'chmod\s+-R\s+777\s+/'
        'curl.*\|\s*(ba)?sh'
        'wget.*\|\s*(ba)?sh'
        'bash\s*<\(curl'
        'bash\s*<\(wget'
        'eval\s.*\$\('
        'python[23]?\s+-c\s+.*os\.(system|popen|exec)'
        'sudo\s+rm\s+-rf\s+/'
        'mv\s+/\s+/dev/null'
        'ln\s+-sf?\s+/dev/null\s+/(etc|usr|bin)'
    )

    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        if echo "$COMMAND" | grep -qiE "$pattern"; then
            jq -n '{
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": "BLOQUEADO: Comando peligroso detectado. Patron: '"$pattern"'"
                }
            }'
            exit 0
        fi
    done

    # Bloquear exposicion de secrets
    SECRET_PATTERNS=(
        'cat.*\.env'
        'echo.*API_KEY'
        'echo.*SECRET'
        'echo.*PASSWORD'
        'echo.*TOKEN'
        'printenv.*KEY'
        'printenv.*SECRET'
    )

    for pattern in "${SECRET_PATTERNS[@]}"; do
        if echo "$COMMAND" | grep -qiE "$pattern"; then
            jq -n '{
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": "BLOQUEADO: Posible exposicion de secrets detectada."
                }
            }'
            exit 0
        fi
    done
fi

# Permitir por defecto
jq -n '{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "Comando seguro"
    }
}'
