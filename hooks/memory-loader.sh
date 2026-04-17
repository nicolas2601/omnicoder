#!/usr/bin/env bash
# ============================================================
# OmniCoder - Memory Loader (SessionStart)
# Inyecta memoria global (~/.omnicoder/memory/) y memoria de proyecto
# (./.omnicoder/memory/) como contexto inicial.
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || pwd)

GLOBAL_MEM_DIR="$HOME/.omnicoder/memory"
PROJECT_MEM_DIR="$CWD/.omnicoder/memory"

CONTEXT=""

# v4.3.1: limites ultra-agresivos (-52% vs v4.3).
# Solo patterns + feedback por default. Resto se carga bajo demanda via /memory.
MAX_LINES=12

MAX_TOTAL_CHARS=1200
TOTAL_CHARS=0

append_file() {
    local f="$1" label="$2"
    [[ -f "$f" ]] || return 0
    # Skip binary files
    file -b --mime "$f" 2>/dev/null | grep -q 'text/' || return 0
    # Skip if total limit reached
    [[ "$TOTAL_CHARS" -ge "$MAX_TOTAL_CHARS" ]] && return 0
    local content
    content=$(head -n "$MAX_LINES" "$f" 2>/dev/null)
    [[ -z "$content" ]] && return
    TOTAL_CHARS=$((TOTAL_CHARS + ${#content}))
    CONTEXT+="

## [$label] $(basename "$f")
$content"
}

# 1. Memoria global: solo semantic memory por default.
#    Episodic (learned/causal/trajectories) va bajo demanda via /memory.
if [[ -d "$GLOBAL_MEM_DIR" ]]; then
    append_file "$GLOBAL_MEM_DIR/patterns.md" "PAT"
    append_file "$GLOBAL_MEM_DIR/feedback.md" "FB"
fi

# 2. Memoria del proyecto actual (si existe y no es el mismo path que el global)
GLOBAL_REAL=$(readlink -f "$GLOBAL_MEM_DIR" 2>/dev/null || echo "$GLOBAL_MEM_DIR")
PROJECT_REAL=$(readlink -f "$PROJECT_MEM_DIR" 2>/dev/null || echo "$PROJECT_MEM_DIR")
if [[ -d "$PROJECT_MEM_DIR" ]] && [[ "$GLOBAL_REAL" != "$PROJECT_REAL" ]]; then
    for f in "$PROJECT_MEM_DIR"/*.md; do
        [[ -f "$f" ]] || continue
        append_file "$f" "PROYECTO:$(basename "$f" .md)"
    done
fi

# 3. Detectar stack rapido (complemento al session-init)
STACK=""
[[ -f "$CWD/package.json" ]] && STACK+="Node.js "
[[ -f "$CWD/requirements.txt" || -f "$CWD/pyproject.toml" ]] && STACK+="Python "
[[ -f "$CWD/Cargo.toml" ]] && STACK+="Rust "
[[ -f "$CWD/go.mod" ]] && STACK+="Go "
[[ -f "$CWD/composer.json" ]] && STACK+="PHP "
[[ -f "$CWD/Gemfile" ]] && STACK+="Ruby "

if [[ -n "$CONTEXT" ]] || [[ -n "$STACK" ]]; then
    HEADER="[MEM] stack=${STACK:-?} | /memory para cargar learned/trajectories/causal."
    FULL="$HEADER$CONTEXT"
    jq -n --arg ctx "$FULL" '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
else
    echo '{}'
fi
