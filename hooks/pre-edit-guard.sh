#!/usr/bin/env bash
# ============================================================
# OmniCoder - Pre-Edit Guard Hook (PreToolUse: Edit|Write)
# v4.4: 13 archivos protegidos fusionados + una sola jq call.
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

# Early-exit: si no hay file_path, allow (evita basename/dirname con "")
case "$INPUT" in
    *'"file_path"'*) ;;
    *)
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"no-path"}}\n'
        exit 0 ;;
esac

# v4.4: una sola jq call para file_path + content (antes 3 jq).
read -r FILE_PATH CONTENT < <(echo "$INPUT" | jq -r '[(.tool_input.file_path // ""), ((.tool_input.content // .tool_input.new_string // "") | tostring | @base64)] | @tsv' 2>/dev/null || echo -e "\t")
CONTENT=$(echo "$CONTENT" | base64 -d 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"empty-path"}}\n'
    exit 0
fi

BASENAME="${FILE_PATH##*/}"
DIRPATH="${FILE_PATH%/*}"
[[ "$DIRPATH" == "$FILE_PATH" ]] && DIRPATH="."

# v4.4: todos los archivos protegidos en un solo case (case-sensitive match).
# Antes: for loop de 13 iteraciones con [[ ]] y jq llamada en match.
DENY_REASON=""
case "$BASENAME" in
    .env|.env.local|.env.production|credentials.json|serviceAccountKey.json|id_rsa|id_ed25519|id_ecdsa|id_dsa|.npmrc|.pypirc|oauth_creds.json|token.json)
        DENY_REASON="Archivo sensible protegido ($BASENAME)" ;;
    .env.*)
        DENY_REASON="Archivo de entorno (.env.*)" ;;
    *.pem) DENY_REASON="Certificado SSL (*.pem)" ;;
    *.key) DENY_REASON="Clave privada (*.key)" ;;
    *.p12) DENY_REASON="Certificado PKCS12 (*.p12)" ;;
    *.pfx) DENY_REASON="Certificado PKCS12 (*.pfx)" ;;
    service-account*.json) DENY_REASON="Service account credentials" ;;
esac

# Check sensitive directory paths (~/.ssh/, ~/.gnupg/) - directo, sin jq
if [[ -z "$DENY_REASON" ]]; then
    case "$DIRPATH" in
        */.ssh*|*/.gnupg*)
            DENY_REASON="Archivo en directorio sensible ($DIRPATH)" ;;
    esac
fi

# v4.3.2: blacklist de paths de sistema (fuera de $HOME). Antes el guard
# permitia editar /etc/passwd, /boot/grub, /usr/bin, /sys/*, /proc/*, /dev/*
# — fallo de defensa en profundidad reportado en bug hunt.
if [[ -z "$DENY_REASON" ]]; then
    case "$FILE_PATH" in
        /etc/*|/boot/*|/sys/*|/proc/*|/dev/*|/root/*|/var/log/*)
            DENY_REASON="Path de sistema protegido ($FILE_PATH). Usa sudo manual si es necesario." ;;
        /usr/*|/bin/*|/sbin/*|/lib/*|/lib64/*|/opt/*)
            # Permitir solo dentro de /usr/local/share/* y similares donde apps de usuario escriben
            case "$FILE_PATH" in
                /usr/local/share/*|/usr/local/lib/python*/site-packages/*) ;;  # excepciones
                *) DENY_REASON="Path de sistema protegido ($FILE_PATH). Usa sudo manual si es necesario." ;;
            esac ;;
    esac
fi

if [[ -n "$DENY_REASON" ]]; then
    jq -n --arg reason "BLOQUEADO: $DENY_REASON. No se permite edicion automatica." '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": $reason
        }
    }'
    exit 0
fi

# Detectar secrets en contenido nuevo (solo si hay contenido)
if [[ -n "$CONTENT" ]] && echo "$CONTENT" | grep -qiE '(sk-[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|-----BEGIN (RSA |EC )?PRIVATE KEY)'; then
    jq -n '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "BLOQUEADO: Se detecto un posible secret/API key en el contenido. Usa variables de entorno en su lugar."
        }
    }'
    exit 0
fi

# Permitir por defecto (printf en vez de jq -n)
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Edicion segura"}}\n'
