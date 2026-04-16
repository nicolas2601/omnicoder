#!/usr/bin/env bash
# ============================================================
# OmniCoder - Skill Usage Tracker (PostToolUse)
# Detecta cuando el router sugirió un skill con score alto y
# el agente NO lo usó. Registra en ignored-skills.md para que la
# próxima vez el router lo haga OBLIGATORIO.
#
# Esto cierra el loop: si ignoras 3+ veces un skill con score>=3,
# el router lo eleva a score +2 (llega a HARD enforcement).
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)

CACHE_DIR="$HOME/.omnicoder/.cache"
MEM_DIR="$HOME/.omnicoder/memory"
SUGGESTIONS_LOG="$CACHE_DIR/last-suggestions.json"

# No hay sugerencia previa -> nada que trackear
[[ -f "$SUGGESTIONS_LOG" ]] || exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")

SUGGESTED_SKILL=$(jq -r '.top_skill // ""' "$SUGGESTIONS_LOG" 2>/dev/null)
SUGGESTED_SCORE=$(jq -r '.score // 0' "$SUGGESTIONS_LOG" 2>/dev/null)
SUGGESTED_LEVEL=$(jq -r '.level // ""' "$SUGGESTIONS_LOG" 2>/dev/null)
SUGGESTED_TS=$(jq -r '.ts // ""' "$SUGGESTIONS_LOG" 2>/dev/null)

[[ -z "$SUGGESTED_SKILL" ]] && exit 0
[[ "$SUGGESTED_SCORE" -lt 3 ]] && exit 0

# Check si el tool actual ES la invocación del skill sugerido
# Los skills se invocan via /skills <name> (el agente lo hace
# leyendo SKILL.md y siguiendo sus instrucciones, NO es una tool específica).
# Heurística: si en los ultimos 60s un Read o Bash toco el SKILL.md
# del skill sugerido, asumimos que se usó.

USED=0
if [[ "$TOOL_NAME" == "Read" ]]; then
    FP=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null)
    if [[ "$FP" == *"/skills/$SUGGESTED_SKILL/"* ]] || [[ "$FP" == *"/skills/$SUGGESTED_SKILL.md" ]]; then
        USED=1
    fi
fi

if [[ "$TOOL_NAME" == "Bash" ]]; then
    CMD=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null)
    if echo "$CMD" | grep -q "$SUGGESTED_SKILL"; then
        USED=1
    fi
fi

if [[ "$USED" == "1" ]]; then
    # Skill usado correctamente. Invalidar el tracking.
    rm -f "$SUGGESTIONS_LOG"
    # Registrar uso positivo en skill-stats
    STATS_FILE="$MEM_DIR/skill-stats.json"
    mkdir -p "$MEM_DIR"
    if [[ ! -f "$STATS_FILE" ]]; then echo '{}' > "$STATS_FILE"; fi
    (flock -w 2 200
    jq --arg s "$SUGGESTED_SKILL" '
        .[$s] = ((.[$s] // {used:0, ignored:0}) | .used += 1 | .last_used = now | tostring)
    ' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE" 2>/dev/null || true
    ) 200>"$STATS_FILE.lock"
    exit 0
fi

# El tool ya se ejecutó y no se usó el skill. Cuenta como "ignorado".
# Pero solo si ya pasaron 2+ acciones desde la sugerencia (para no ser injusto).
NOW=$(date +%s)
SUG_EPOCH=$(date -d "$SUGGESTED_TS" +%s 2>/dev/null || echo "$NOW")
ELAPSED=$((NOW - SUG_EPOCH))

# Si ya pasaron >30s y ejecutamos Bash/Edit sin tocar el skill -> ignored
if [[ "$ELAPSED" -gt 30 ]] && [[ "$TOOL_NAME" =~ ^(Bash|Edit|Write)$ ]]; then
    mkdir -p "$MEM_DIR"
    IGNORED_FILE="$MEM_DIR/ignored-skills.md"

    if [[ ! -f "$IGNORED_FILE" ]]; then
        cat > "$IGNORED_FILE" <<'EOF'
# Skills Ignorados (tracking para enforcement)

Cada vez que el router sugiere un skill con score>=3 y el agente NO lo usa,
se registra aquí. Si un skill se ignora 3+ veces, el router lo eleva a
OBLIGATORIO automáticamente.

Formato: `NOMBRE_SKILL | TIMESTAMP | SCORE | LEVEL | PROMPT_SNIPPET`

---
EOF
    fi

    PROMPT_SNIP=$(jq -r '.prompt // ""' "$SUGGESTIONS_LOG" 2>/dev/null | head -c 100)
    (flock -w 2 200; echo "$SUGGESTED_SKILL | $(date -Iseconds) | $SUGGESTED_SCORE | $SUGGESTED_LEVEL | $PROMPT_SNIP" >> "$IGNORED_FILE") 200>"$IGNORED_FILE.lock"

    # Actualizar stats
    STATS_FILE="$MEM_DIR/skill-stats.json"
    if [[ ! -f "$STATS_FILE" ]]; then echo '{}' > "$STATS_FILE"; fi
    (flock -w 2 200
    jq --arg s "$SUGGESTED_SKILL" '
        .[$s] = ((.[$s] // {used:0, ignored:0}) | .ignored += 1)
    ' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE" 2>/dev/null || true
    ) 200>"$STATS_FILE.lock"

    # Invalidar (ya procesamos)
    rm -f "$SUGGESTIONS_LOG"
fi

exit 0
