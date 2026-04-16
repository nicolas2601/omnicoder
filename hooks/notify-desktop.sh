#!/usr/bin/env bash
# ============================================================
# OmniCoder - Desktop Notification (Notification)
# Envia notificaciones nativas cuando OmniCoder necesita atencion
# ============================================================
set -euo pipefail

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.message // "OmniCoder necesita tu atencion"')

# Linux (notify-send)
if command -v notify-send &>/dev/null; then
    notify-send "OmniCoder" "$MESSAGE" --icon=terminal --urgency=normal 2>/dev/null || true
# macOS (osascript)
elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MESSAGE\" with title \"OmniCoder\"" 2>/dev/null || true
fi

exit 0
