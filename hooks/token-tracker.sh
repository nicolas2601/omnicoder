#!/usr/bin/env bash
# OmniCoder - Token Usage Tracker (PostToolUse)
# Tracks estimated token consumption per session
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

# Extract token info from tool output if available
OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null || echo "")
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

LOG_DIR="$HOME/.omnicoder/logs"
mkdir -p "$LOG_DIR"
USAGE_FILE="$LOG_DIR/token-usage.jsonl"

# Estimate tokens based on output length (rough: 1 token ≈ 4 chars)
OUTPUT_LEN=${#OUTPUT}
EST_TOKENS=$(( OUTPUT_LEN / 4 ))

# Log entry
TIMESTAMP=$(date -Iseconds)
echo "{\"ts\":\"$TIMESTAMP\",\"tool\":\"$TOOL_NAME\",\"est_tokens\":$EST_TOKENS,\"chars\":$OUTPUT_LEN}" >> "$USAGE_FILE"

# Rotate if > 10000 lines
LINE_COUNT=$(wc -l < "$USAGE_FILE" 2>/dev/null || echo 0)
if [[ "$LINE_COUNT" -gt 10000 ]]; then
    tail -n 5000 "$USAGE_FILE" > "$USAGE_FILE.tmp" && mv "$USAGE_FILE.tmp" "$USAGE_FILE"
fi

echo '{}'
