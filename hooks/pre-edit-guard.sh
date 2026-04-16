#!/usr/bin/env bash
# ============================================================
# OmniCoder - Pre-Edit Guard Hook (PreToolUse: Edit|Write)
# Previene edicion de archivos sensibles y protege secrets
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
CONTENT=$(echo "$TOOL_INPUT" | jq -r '.content // .new_string // ""')

# Bloquear edicion de archivos sensibles (basename exacto)
PROTECTED_FILES=(
    '.env'
    '.env.local'
    '.env.production'
    'credentials.json'
    'serviceAccountKey.json'
    'id_rsa'
    'id_ed25519'
    'id_ecdsa'
    'id_dsa'
    '.npmrc'
    '.pypirc'
    'oauth_creds.json'
    'token.json'
)

BASENAME=$(basename "$FILE_PATH" 2>/dev/null || echo "")
DIRPATH=$(dirname "$FILE_PATH" 2>/dev/null || echo "")

# Check exact basename matches
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

# Check basename glob patterns (.env.*, *.pem, *.key, *.p12, *.pfx, service-account*.json)
DENY_REASON=""
if [[ "$BASENAME" == .env.* ]]; then
    DENY_REASON="Archivo de entorno (.env.*)"
elif [[ "$BASENAME" == *.pem ]]; then
    DENY_REASON="Certificado SSL (*.pem)"
elif [[ "$BASENAME" == *.key ]]; then
    DENY_REASON="Clave privada (*.key)"
elif [[ "$BASENAME" == *.p12 ]]; then
    DENY_REASON="Certificado PKCS12 (*.p12)"
elif [[ "$BASENAME" == *.pfx ]]; then
    DENY_REASON="Certificado PKCS12 (*.pfx)"
elif [[ "$BASENAME" == service-account*.json ]]; then
    DENY_REASON="Service account credentials"
fi

if [[ -n "$DENY_REASON" ]]; then
    jq -n --arg reason "BLOQUEADO: $DENY_REASON — $BASENAME. No se permite edicion automatica." '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": $reason
        }
    }'
    exit 0
fi

# Check sensitive directory paths (~/.ssh/, ~/.gnupg/)
if [[ "$DIRPATH" == */.ssh* || "$DIRPATH" == */.gnupg* ]]; then
    jq -n --arg reason "BLOQUEADO: Archivo en directorio sensible ($DIRPATH). No se permite edicion automatica." '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": $reason
        }
    }'
    exit 0
fi

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
