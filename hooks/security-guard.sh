#!/usr/bin/env bash
# ============================================================
# OmniCoder - Security Guard Hook (PreToolUse: Bash)
# Bloquea comandos peligrosos y protege secrets
# ============================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')

if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

    # Bloquear comandos destructivos
    DANGEROUS_PATTERNS=(
        'rm -rf /'
        'rm -rf ~'
        'rm -rf \*'
        ':(){ :|:& };:'
        'mkfs\.'
        'dd if=/dev/zero'
        '> /dev/sda'
        'chmod -R 777 /'
        'curl.*| ?sh'
        'wget.*| ?sh'
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
