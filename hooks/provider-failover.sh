#!/usr/bin/env bash
# ============================================================
# OmniCoder - Provider Failover Detection (PostToolUse)
# Detects API failures and suggests provider switch
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)
# Parse the tool output for error patterns
OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null || echo "")

# Check for provider failure patterns
FAILOVER_NEEDED=false
REASON=""

if echo "$OUTPUT" | grep -qiE '429|rate.?limit|too many requests'; then
    FAILOVER_NEEDED=true
    REASON="Rate limit (429)"
elif echo "$OUTPUT" | grep -qiE '503|service.?unavailable'; then
    FAILOVER_NEEDED=true
    REASON="Service unavailable (503)"
elif echo "$OUTPUT" | grep -qiE 'timeout|timed?.?out|ETIMEDOUT|ECONNREFUSED'; then
    FAILOVER_NEEDED=true
    REASON="Connection timeout"
elif echo "$OUTPUT" | grep -qiE '401|unauthorized|invalid.*key|authentication'; then
    FAILOVER_NEEDED=true
    REASON="Auth failed (401) - API key may be invalid"
fi

if [[ "$FAILOVER_NEEDED" == true ]]; then
    # Log the failure
    LOG_DIR="$HOME/.omnicoder/logs"
    mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] PROVIDER FAILURE: $REASON" >> "$LOG_DIR/provider-failures.log"

    # Count recent failures (last 5 minutes)
    RECENT=$(grep -c "$(date +%Y-%m-%dT%H:%M 2>/dev/null || date +%Y-%m-%d)" "$LOG_DIR/provider-failures.log" 2>/dev/null || echo 0)

    # Emit warning
    MSG="[PROVIDER-ISSUE] $REASON detectado."
    if [[ "$RECENT" -ge 3 ]]; then
        MSG="$MSG Multiples fallas recientes ($RECENT). Considera cambiar provider: bash ~/.omnicoder/scripts/switch-provider.sh <provider>"
    fi

    jq -n --arg msg "$MSG" '{
        "hookSpecificOutput": {
            "additionalContext": $msg
        }
    }'
else
    echo '{}'
fi
