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

# Portable lock helper (flock on Linux/macOS, mkdir fallback on Git Bash Windows)
# shellcheck source=_flock-compat.sh
. "$(dirname "${BASH_SOURCE[0]}")/_flock-compat.sh" 2>/dev/null || true

INPUT=$(cat)

CACHE_DIR="$HOME/.omnicoder/.cache"
MEM_DIR="$HOME/.omnicoder/memory"
SUGGESTIONS_LOG="$CACHE_DIR/last-suggestion.json"

# No hay sugerencia previa -> nada que trackear
[[ -f "$SUGGESTIONS_LOG" ]] || exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")

SUGGESTED_SKILL=$(jq -r '.skill // .top_skill // ""' "$SUGGESTIONS_LOG" 2>/dev/null)
SUGGESTED_SCORE=$(jq -r '.skill_score // .score // 0' "$SUGGESTIONS_LOG" 2>/dev/null)
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
    _bump_used() {
        jq --arg s "$SUGGESTED_SKILL" '
            .[$s] = ((.[$s] // {used:0, ignored:0}) | .used += 1)
        ' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE" 2>/dev/null || true
    }
    if command -v oc_with_lock >/dev/null 2>&1; then
        oc_with_lock "$STATS_FILE" _bump_used
    else
        (flock -w 2 200; _bump_used) 200>"$STATS_FILE.lock"
    fi
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
    IGN_LINE="$SUGGESTED_SKILL | $(date -Iseconds) | $SUGGESTED_SCORE | $SUGGESTED_LEVEL | $PROMPT_SNIP"
    if command -v oc_locked_append >/dev/null 2>&1; then
        oc_locked_append "$IGNORED_FILE" "$IGN_LINE"
    else
        (flock -w 2 200; printf '%s\n' "$IGN_LINE" >> "$IGNORED_FILE") 200>"$IGNORED_FILE.lock"
    fi

    # Actualizar stats
    STATS_FILE="$MEM_DIR/skill-stats.json"
    if [[ ! -f "$STATS_FILE" ]]; then echo '{}' > "$STATS_FILE"; fi
    _bump_ignored() {
        jq --arg s "$SUGGESTED_SKILL" '
            .[$s] = ((.[$s] // {used:0, ignored:0}) | .ignored += 1)
        ' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE" 2>/dev/null || true
    }
    if command -v oc_with_lock >/dev/null 2>&1; then
        oc_with_lock "$STATS_FILE" _bump_ignored
    else
        (flock -w 2 200; _bump_ignored) 200>"$STATS_FILE.lock"
    fi

    # Invalidar (ya procesamos)
    rm -f "$SUGGESTIONS_LOG"
fi

exit 0
