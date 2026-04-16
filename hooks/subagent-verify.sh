#!/usr/bin/env bash
# ============================================================
# OmniCoder - Subagent Verifier (PostToolUse matcher=Task)
#
# Verifica que los subagentes declararon evidencia real de su trabajo.
# Parsea el bloque <verification>...</verification> del output del
# subagent y valida:
#   - files: cada archivo existe y fue modificado recientemente
#   - commands: fueron loggeados por post-tool-logger.sh
#   - tests: si tests=true, valida que haya evidencia
#
# Si algo falla, emite additionalContext con [VERIFICACION-FALLIDA]
# para que el agente principal re-invoque o confirme manualmente.
# ============================================================
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" != "Task" ]] && { echo '{}'; exit 0; }

TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_response // .tool_output // .output // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && CWD="$PWD"

LOG_DIR="$HOME/.omnicoder/logs"
VERIFY_LOG="$LOG_DIR/subagent-verify.log"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --------------------------------------------------------
# Extraer bloque <verification>...</verification>
# --------------------------------------------------------
VERIFICATION_BLOCK=$(echo "$TOOL_OUTPUT" | awk '/<verification>/,/<\/verification>/' | sed '1d;$d')

if [[ -z "$VERIFICATION_BLOCK" ]]; then
    CTX="⚠️ [VERIFICACION-FALLIDA] El subagente NO incluyo el bloque <verification>. No hay evidencia de trabajo real. ACCIONES OBLIGATORIAS antes de aceptar su output:
1. Pide al subagent que re-ejecute con el contrato: <verification>files: [...], commands: [...], tests: true|false</verification>
2. O verifica manualmente con: Bash(git diff --stat), Read(archivos mencionados).
3. NO reportes al usuario 'listo' sin verificar."
    echo "$TIMESTAMP|$SESSION_ID|NO_CONTRACT" >> "$VERIFY_LOG"
    jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
    exit 0
fi

# --------------------------------------------------------
# Parse: soporta JSON o YAML-like simple
# --------------------------------------------------------
FILES=$(echo "$VERIFICATION_BLOCK" | grep -iE '^[[:space:]]*files[[:space:]]*[:=]' | head -1 | sed -E 's/^[^:=]*[:=][[:space:]]*//' | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true)
COMMANDS=$(echo "$VERIFICATION_BLOCK" | grep -iE '^[[:space:]]*commands[[:space:]]*[:=]' | head -1 | sed -E 's/^[^:=]*[:=][[:space:]]*//' | tr -d '[]"' || true)
TESTS=$(echo "$VERIFICATION_BLOCK" | grep -iE '^[[:space:]]*tests[[:space:]]*[:=]' | head -1 | sed -E 's/^[^:=]*[:=][[:space:]]*//' | tr -d '[]" ' || true)

ISSUES=()

# --------------------------------------------------------
# Validar archivos declarados
# --------------------------------------------------------
if [[ -n "$FILES" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        # Resolver relativo al cwd
        [[ "$f" != /* ]] && f="$CWD/$f"
        if [[ ! -e "$f" ]]; then
            ISSUES+=("archivo declarado NO existe: $f")
        else
            # Modificado en los ultimos 5 minutos?
            MTIME=$(stat -c%Y "$f" 2>/dev/null || echo 0)
            NOW=$(date +%s)
            AGE=$((NOW - MTIME))
            if [[ "$AGE" -gt 300 ]]; then
                ISSUES+=("archivo $f NO fue modificado recientemente (hace ${AGE}s)")
            fi
        fi
    done <<< "$FILES"
fi

# --------------------------------------------------------
# Validar comandos contra operations.log (ultimos 10 min)
# --------------------------------------------------------
if [[ -n "$COMMANDS" ]] && [[ "$COMMANDS" != "[]" ]] && [[ "$COMMANDS" != "none" ]]; then
    OPS_LOG="$LOG_DIR/operations.log"
    if [[ -f "$OPS_LOG" ]]; then
        RECENT_BASH=$(tail -200 "$OPS_LOG" | grep "|Bash|" | wc -l)
        [[ "$RECENT_BASH" -eq 0 ]] && ISSUES+=("declaro commands ejecutados pero operations.log no registra Bash reciente")
    fi
fi

# --------------------------------------------------------
# Validar tests
# --------------------------------------------------------
if [[ "$TESTS" == "true" ]]; then
    TEST_EVIDENCE=$(echo "$TOOL_OUTPUT" | grep -iE 'pass(ed|ing)|PASS|✓|ok [0-9]|[0-9]+ tests' | head -3)
    [[ -z "$TEST_EVIDENCE" ]] && ISSUES+=("declaro tests=true pero NO hay evidencia de ejecucion de tests en el output")
fi

# --------------------------------------------------------
# Emitir resultado
# --------------------------------------------------------
if [[ ${#ISSUES[@]} -gt 0 ]]; then
    ISSUE_LIST=""
    for i in "${ISSUES[@]}"; do
        ISSUE_LIST+="  - $i"$'\n'
    done
    CTX="⚠️ [VERIFICACION-FALLIDA] El subagente declaro trabajo pero la evidencia NO coincide:
$ISSUE_LIST
ACCIONES OBLIGATORIAS:
1. NO reportes 'listo' al usuario.
2. Verifica manualmente con Bash/Read cada archivo que el subagent dijo cambiar.
3. Si falta trabajo real, re-invoca el subagent con correcciones especificas."
    echo "$TIMESTAMP|$SESSION_ID|FAILED|${#ISSUES[@]}" >> "$VERIFY_LOG"
    jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
else
    echo "$TIMESTAMP|$SESSION_ID|OK" >> "$VERIFY_LOG"
    echo '{}'
fi
