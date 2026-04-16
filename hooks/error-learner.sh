#!/usr/bin/env bash
# ============================================================
# OmniCoder - Error Learner (PostToolUse)
# Detecta fallas en tools (exit != 0, stderr con error/exception)
# y registra patrones en ~/.omnicoder/memory/learned.md para evitar
# repetir los mismos errores en el futuro.
# ============================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null || echo "")
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0' 2>/dev/null || echo 0)

# Solo aprende si hay error claro
IS_ERROR=0
if [[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]]; then
    IS_ERROR=1
fi

# Buscar palabras clave de error en el response
if echo "$TOOL_RESPONSE" | grep -qiE '(command not found|permission denied|no such file|syntaxerror|typeerror|modulenotfound|cannot find module|fatal:|error:|failed to)'; then
    IS_ERROR=1
fi

[[ "$IS_ERROR" == "0" ]] && exit 0

MEM_DIR="$HOME/.omnicoder/memory"
mkdir -p "$MEM_DIR"
LEARNED_FILE="$MEM_DIR/learned.md"

# Inicializar archivo si no existe
if [[ ! -f "$LEARNED_FILE" ]]; then
    cat > "$LEARNED_FILE" <<'EOF'
# Errores Aprendidos

Registro automatico de errores detectados por error-learner.sh.
Cada entrada contiene: fecha, herramienta, input y snippet del error.
Usa esto antes de repetir comandos similares.

---
EOF
fi

# Extraer comando/archivo afectado para contexto
TARGET=""
if [[ "$TOOL_NAME" == "Bash" ]]; then
    TARGET=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null | head -c 200)
elif [[ "$TOOL_NAME" =~ ^(Edit|Write|Read)$ ]]; then
    TARGET=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null)
fi

# Snippet del error (max 300 chars, sin saltos raros)
ERROR_SNIPPET=$(echo "$TOOL_RESPONSE" | tr '\n' ' ' | head -c 300)

TIMESTAMP=$(date -Iseconds)

# Deduplicar: si el mismo target+error ya existe, no duplicar
SIG=$(echo "${TARGET}${ERROR_SNIPPET}" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "")
if [[ -n "$SIG" ]] && grep -q "sig:$SIG" "$LEARNED_FILE" 2>/dev/null; then
    exit 0
fi

cat >> "$LEARNED_FILE" <<EOF

### $TIMESTAMP | $TOOL_NAME
- **Target**: \`$TARGET\`
- **Error**: $ERROR_SNIPPET
- sig:$SIG
EOF

# Trimmear si pasa 500 entradas (mantener solo ultimas 200)
LINE_COUNT=$(wc -l < "$LEARNED_FILE")
if [[ "$LINE_COUNT" -gt 2500 ]]; then
    HEADER=$(head -n 7 "$LEARNED_FILE")
    TAIL=$(tail -n 1000 "$LEARNED_FILE")
    echo -e "$HEADER\n\n$TAIL" > "$LEARNED_FILE"
fi

exit 0
