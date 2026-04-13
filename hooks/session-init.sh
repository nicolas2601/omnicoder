#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Session Init (SessionStart)
# Carga automaticamente el ultimo handoff y contexto del proyecto
# ============================================================
set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

CONTEXT=""

# Buscar ultimo handoff del proyecto actual
HANDOFF_DIR="$CWD/.qwen"
if [[ -d "$HANDOFF_DIR" ]]; then
    LATEST_HANDOFF=$(ls -t "$HANDOFF_DIR"/handoff-*.md 2>/dev/null | head -1)
    if [[ -n "$LATEST_HANDOFF" ]]; then
        HANDOFF_AGE=$(( $(date +%s) - $(stat -c%Y "$LATEST_HANDOFF" 2>/dev/null || stat -f%m "$LATEST_HANDOFF" 2>/dev/null || echo 0) ))
        # Solo cargar si tiene menos de 24 horas
        if [[ "$HANDOFF_AGE" -lt 86400 ]]; then
            CONTEXT="[HANDOFF DISPONIBLE] Sesion anterior detectada: $LATEST_HANDOFF ($(( HANDOFF_AGE / 3600 ))h atras). Usa: lee $LATEST_HANDOFF para retomar donde quedamos."
        fi
    fi
fi

# Detectar stack del proyecto
if [[ -f "$CWD/package.json" ]]; then
    CONTEXT="$CONTEXT | Proyecto Node.js detectado."
elif [[ -f "$CWD/requirements.txt" ]] || [[ -f "$CWD/pyproject.toml" ]]; then
    CONTEXT="$CONTEXT | Proyecto Python detectado."
elif [[ -f "$CWD/Cargo.toml" ]]; then
    CONTEXT="$CONTEXT | Proyecto Rust detectado."
elif [[ -f "$CWD/go.mod" ]]; then
    CONTEXT="$CONTEXT | Proyecto Go detectado."
fi

# Detectar git branch
if [[ -d "$CWD/.git" ]]; then
    BRANCH=$(cd "$CWD" && git branch --show-current 2>/dev/null || echo "")
    if [[ -n "$BRANCH" ]]; then
        CONTEXT="$CONTEXT | Branch: $BRANCH"
    fi
fi

if [[ -n "$CONTEXT" ]]; then
    jq -n --arg ctx "$CONTEXT" '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx
        }
    }'
else
    echo '{}'
fi
