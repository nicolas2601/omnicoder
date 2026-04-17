#!/usr/bin/env bash
# ============================================================
# OmniCoder - Success Learner (PostToolUse)
# Captura trayectorias EXITOSAS (tests pasan, build ok, commits
# limpios) y las destila en memory/trajectories.md como patrones
# reutilizables (ExpeL / ReasoningBank pattern).
#
# Filosofía: aprender de éxitos = patrones positivos.
# Aprender solo de errores sesga al agente a ser pesimista.
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

# Portable lock helper (flock on Linux/macOS, mkdir fallback on Git Bash Windows)
# shellcheck source=_flock-compat.sh
. "$(dirname "${BASH_SOURCE[0]}")/_flock-compat.sh" 2>/dev/null || true

INPUT=$(cat | tr '\n' ' ' | tr '\r' ' ')

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null || echo "")
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0' 2>/dev/null || echo 0)

# Solo procesa si fue exitoso
[[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]] && exit 0

# Detectar "signal" de éxito significativo
SIGNAL=""
if [[ "$TOOL_NAME" == "Bash" ]]; then
    CMD=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null | head -c 300)
    # Patrones de éxito que valen la pena aprender
    if echo "$CMD" | grep -qE '(npm test|pytest|go test|cargo test|jest|vitest)'; then
        if echo "$TOOL_RESPONSE" | grep -qiE '(pass|ok|success|[0-9]+ passed|tests? passed)'; then
            SIGNAL="tests-pass"
        fi
    elif echo "$CMD" | grep -qE '(npm run build|cargo build|go build|tsc|vite build|next build)'; then
        if ! echo "$TOOL_RESPONSE" | grep -qiE '(error|failed)'; then
            SIGNAL="build-ok"
        fi
    elif echo "$CMD" | grep -qE '^git commit'; then
        SIGNAL="commit"
    elif echo "$CMD" | grep -qE '(npm run lint|eslint|ruff|clippy)'; then
        if ! echo "$TOOL_RESPONSE" | grep -qiE '(error|[0-9]+ problems?)'; then
            SIGNAL="lint-clean"
        fi
    fi
fi

[[ -z "$SIGNAL" ]] && exit 0

MEM_DIR="$HOME/.omnicoder/memory"
mkdir -p "$MEM_DIR"
TRAJ_FILE="$MEM_DIR/trajectories.md"

if [[ ! -f "$TRAJ_FILE" ]]; then
    cat > "$TRAJ_FILE" <<'EOF'
# Trayectorias Exitosas (Episodic Memory)

Secuencias de herramientas que funcionaron. Destiladas periódicamente
en `patterns.md` como reglas semánticas reutilizables.

Formato: `TIMESTAMP | SIGNAL | TOOL | SNIPPET`

---
EOF
fi

TIMESTAMP=$(date -Iseconds)
SNIPPET=$(echo "$TOOL_INPUT" | jq -r '.command // .file_path // ""' 2>/dev/null | head -c 150)
CWD=$(pwd 2>/dev/null | head -c 100)

# Dedupe por signal+snippet en ultimas 20 lineas
RECENT=$(tail -n 20 "$TRAJ_FILE" 2>/dev/null || echo "")
SIG=$(echo "${SIGNAL}${SNIPPET}" | md5sum 2>/dev/null | cut -d' ' -f1)
if echo "$RECENT" | grep -q "sig:$SIG"; then
    exit 0
fi

LINE="- $TIMESTAMP | $SIGNAL | $TOOL_NAME | \`$SNIPPET\` | cwd:$CWD | sig:$SIG"
if command -v oc_locked_append >/dev/null 2>&1; then
    oc_locked_append "$TRAJ_FILE" "$LINE"
else
    (flock -w 2 200; printf '%s\n' "$LINE" >> "$TRAJ_FILE") 200>"$TRAJ_FILE.lock"
fi

# Trim: mantener ultimas 500 trayectorias
LINE_COUNT=$(wc -l < "$TRAJ_FILE")
if [[ "$LINE_COUNT" -gt 600 ]]; then
    _trim_traj() {
        HEADER=$(head -n 7 "$TRAJ_FILE")
        TAIL=$(tail -n 500 "$TRAJ_FILE")
        printf '%s\n\n%s\n' "$HEADER" "$TAIL" > "$TRAJ_FILE"
    }
    if command -v oc_with_lock >/dev/null 2>&1; then
        oc_with_lock "$TRAJ_FILE" _trim_traj
    else
        (flock -w 2 200; _trim_traj) 200>"$TRAJ_FILE.lock"
    fi
fi

exit 0
