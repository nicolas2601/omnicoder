#!/usr/bin/env bash
# ============================================================
# OmniCoder - Pre-Edit Guard Hook (PreToolUse: Edit|Write)
# Previene edicion de archivos sensibles y protege secrets
# ============================================================
set -euo pipefail

INPUT=$(cat)

TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
CONTENT=$(echo "$TOOL_INPUT" | jq -r '.content // .new_string // ""')

# Bloquear edicion de archivos sensibles
PROTECTED_FILES=(
    '.env'
    '.env.local'
    '.env.production'
    'credentials.json'
    'serviceAccountKey.json'
    'id_rsa'
    'id_ed25519'
    '.npmrc'
    '.pypirc'
)

BASENAME=$(basename "$FILE_PATH" 2>/dev/null || echo "")
for protected in "${PROTECTED_FILES[@]}"; do
    if [[ "$BASENAME" == "$protected" ]]; then
        jq -n '{
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "BLOQUEADO: Archivo sensible protegido ('"$BASENAME"'). No se permite edicion automatica."
            }
        }'
        exit 0
    fi
done

# Detectar secrets en contenido nuevo
if echo "$CONTENT" | grep -qiE '(sk-[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|-----BEGIN (RSA |EC )?PRIVATE KEY)'; then
    jq -n '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "BLOQUEADO: Se detecto un posible secret/API key en el contenido. Usa variables de entorno en su lugar."
        }
    }'
    exit 0
fi

# Permitir por defecto
jq -n '{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "Edicion segura"
    }
}'
