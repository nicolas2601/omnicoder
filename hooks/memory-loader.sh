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

# Limite de lineas por archivo para no reventar contexto
MAX_LINES=80

MAX_TOTAL_CHARS=8000
TOTAL_CHARS=0

append_file() {
    local f="$1" label="$2"
    [[ -f "$f" ]] || return
    # Skip binary files
    file -b --mime "$f" 2>/dev/null | grep -q 'text/' || return
    # Skip if total limit reached
    [[ "$TOTAL_CHARS" -ge "$MAX_TOTAL_CHARS" ]] && return
    local content
    content=$(head -n "$MAX_LINES" "$f" 2>/dev/null)
    [[ -z "$content" ]] && return
    TOTAL_CHARS=$((TOTAL_CHARS + ${#content}))
    CONTEXT+="

## [$label] $(basename "$f")
$content"
}

# 1. Memoria global (v3): prioriza patrones destilados (semantic memory)
#    sobre casos específicos (episodic). Orden importa:
if [[ -d "$GLOBAL_MEM_DIR" ]]; then
    append_file "$GLOBAL_MEM_DIR/MEMORY.md" "MEMORIA-GLOBAL"
    append_file "$GLOBAL_MEM_DIR/patterns.md" "PATRONES-DESTILADOS"
    append_file "$GLOBAL_MEM_DIR/feedback.md" "FEEDBACK-USUARIO"
    append_file "$GLOBAL_MEM_DIR/causal-edges.md" "CAUSAL-EDGES"
    append_file "$GLOBAL_MEM_DIR/learned.md" "ERRORES-APRENDIDOS"
    # Trayectorias: solo ultimas 10 (episodic, suele ser mucho)
    if [[ -f "$GLOBAL_MEM_DIR/trajectories.md" ]]; then
        TRAJ_TAIL=$(tail -n 10 "$GLOBAL_MEM_DIR/trajectories.md" 2>/dev/null)
        [[ -n "$TRAJ_TAIL" ]] && CONTEXT+="

## [TRAYECTORIAS-RECIENTES] ultimas 10
$TRAJ_TAIL"
    fi
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
    HEADER="[CONTEXTO PERSISTENTE] Memoria cargada desde ~/.omnicoder/memory/ y ./.omnicoder/memory/. Stack: ${STACK:-desconocido}. Usa esta memoria para no repetir errores, respetar preferencias del usuario y entender el proyecto. Si aprendes algo nuevo o el usuario te corrige, actualiza la memoria con /learn o escribe en ~/.omnicoder/memory/learned.md."
    FULL="$HEADER$CONTEXT"
    jq -n --arg ctx "$FULL" '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
else
    echo '{}'
fi
