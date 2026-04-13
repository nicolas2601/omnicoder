#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Desktop Notification (Notification)
# Envia notificaciones nativas cuando Qwen necesita atencion
# ============================================================
set -euo pipefail

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.message // "Qwen Code necesita tu atencion"')

# Linux (notify-send)
if command -v notify-send &>/dev/null; then
    notify-send "Qwen Code" "$MESSAGE" --icon=terminal --urgency=normal 2>/dev/null || true
# macOS (osascript)
elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MESSAGE\" with title \"Qwen Code\"" 2>/dev/null || true
fi

exit 0
