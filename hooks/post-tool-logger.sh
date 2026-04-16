#!/usr/bin/env bash
# ============================================================
# OmniCoder - Post-Tool Logger (PostToolUse)
# Registra operaciones para auditoria y metricas
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

LOG_DIR="$HOME/.omnicoder/logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')

# Log compacto (1 linea por operacion)
echo "${TIMESTAMP}|${SESSION_ID}|${TOOL_NAME}|${CWD}" >> "$LOG_DIR/operations.log"

# Rotar log si supera 10MB
LOG_FILE="$LOG_DIR/operations.log"
if [[ -f "$LOG_FILE" ]]; then
    SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [[ "$SIZE" -gt 10485760 ]]; then
        mv "$LOG_FILE" "$LOG_FILE.$(date '+%Y%m%d')"
        touch "$LOG_FILE"
    fi
fi

# No bloquear ejecucion - solo logging
exit 0
