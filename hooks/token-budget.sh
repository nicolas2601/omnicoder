#!/usr/bin/env bash
# ============================================================
# OmniCoder - Token Budget Monitor (SessionStart)
# Lee ~/.omnicoder/logs/token-usage.jsonl (generado por dispatcher)
# y si el promedio ultimas 10 sesiones supera threshold, emite warning.
# No bloqueante. Solo informa.
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

LOG="$HOME/.omnicoder/logs/token-usage.jsonl"
THRESHOLD=15000

# Si no hay log, no emitir nada
[[ -f "$LOG" ]] || { echo '{}'; exit 0; }

# Ultimas 10 entradas con campo total_tokens (o tokens_input)
AVG=$(tail -n 10 "$LOG" 2>/dev/null \
    | jq -rs 'map(.total_tokens // .tokens_input // .tokens // 0 | tonumber) | if length>0 then (add/length|floor) else 0 end' \
    2>/dev/null || echo 0)

# Sanity
[[ "$AVG" =~ ^[0-9]+$ ]] || AVG=0

if [[ "$AVG" -gt "$THRESHOLD" ]]; then
    MSG="[BUDGET] Sesion promedio usa ${AVG} tokens/tarea. Considera /compact o reducir scope."
    jq -n --arg ctx "$MSG" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$ctx}}'
else
    echo '{}'
fi
