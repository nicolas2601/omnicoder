#!/usr/bin/env bash
# ============================================================
# OmniCoder - Patch Branding
# Reemplaza "Qwen Code" por "OmniCoder" en la TUI del CLI
# y reemplaza el ASCII logo QWEN por OMNI.
# Se ejecuta automaticamente durante la instalacion y al arrancar.
# Seguro: solo modifica strings de display, no logica.
# ============================================================
set -euo pipefail

QUIET="${1:-}"

# Paleta compartida
__PB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -f "$__PB_DIR/_colors.sh" ]]; then
    # shellcheck disable=SC1091
    source "$__PB_DIR/_colors.sh"
else
    CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
fi

log() {
    [[ "$QUIET" == "--quiet" ]] && return
    echo -e "$@"
}

# Detectar ubicacion del CLI
CLI_JS=""
if command -v qwen &>/dev/null; then
    QWEN_PATH=$(which qwen)
    REAL_PATH=$(readlink -f "$QWEN_PATH" 2>/dev/null || echo "$QWEN_PATH")
    CLI_DIR=$(dirname "$REAL_PATH")
    for candidate in \
        "$(npm root -g 2>/dev/null)/@qwen-code/qwen-code/cli.js" \
        "$CLI_DIR/../lib/node_modules/@qwen-code/qwen-code/cli.js" \
        "$CLI_DIR/cli.js" \
        "$HOME/.npm-global/lib/node_modules/@qwen-code/qwen-code/cli.js"; do
        if [[ -f "$candidate" ]]; then
            CLI_JS="$candidate"
            break
        fi
    done
fi

if [[ -z "$CLI_JS" ]] || [[ ! -f "$CLI_JS" ]]; then
    log "  ${YELLOW}!!${NC} No se encontro cli.js de Qwen Code. Patch de branding saltado."
    exit 0
fi

# Verificar si ya esta completamente parcheado (logo + texto)
if grep -q '>_ OmniCoder' "$CLI_JS" 2>/dev/null && ! grep -q 'shortAsciiLogo.*QWEN' "$CLI_JS" 2>/dev/null; then
    # Check if logo is already patched (OMNI instead of QWEN)
    if grep -q 'OMNI' "$CLI_JS" 2>/dev/null; then
        log "  ${GREEN}OK${NC} Branding ya parcheado (OmniCoder)"
        exit 0
    fi
fi

# Backup (solo si no existe ya)
[[ ! -f "${CLI_JS}.bak" ]] && cp "$CLI_JS" "${CLI_JS}.bak" 2>/dev/null || true

# ────────────────────────────────────────
# Patch 1: Reemplazar ASCII logo QWEN -> OMNI
# ────────────────────────────────────────
# El logo original usa Unicode box-drawing chars. Reemplazamos el bloque completo.
# OMNI en el mismo estilo (6 lineas de alto, mismos caracteres Unicode):
OMNI_LOGO='var shortAsciiLogo = `\n \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2557   \u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2557   \u2588\u2588\u2557\u2588\u2588\u2557\n\u2588\u2588\u2554\u2550\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2551\u2588\u2588\u2551\n\u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2554\u2588\u2588\u2588\u2588\u2554\u2588\u2588\u2551\u2588\u2588\u2554\u2588\u2588\u2557 \u2588\u2588\u2551\u2588\u2588\u2551\n\u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2551\u255A\u2588\u2588\u2554\u255D\u2588\u2588\u2551\u2588\u2588\u2551\u255A\u2588\u2588\u2557\u2588\u2588\u2551\u2588\u2588\u2551\n\u255A\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255D\u2588\u2588\u2551 \u255A\u2550\u255D \u2588\u2588\u2551\u2588\u2588\u2551 \u255A\u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2551\n \u255A\u2550\u2550\u2550\u2550\u2550\u255D \u255A\u2550\u255D     \u255A\u2550\u255D\u255A\u2550\u255D  \u255A\u2550\u2550\u2550\u255D\u255A\u2550\u255D\n`;'

# Find and replace the shortAsciiLogo block
# Use python for reliable multiline replacement
python3 -c "
import re, sys
with open('$CLI_JS', 'r') as f:
    content = f.read()

# Replace the shortAsciiLogo block
pattern = r'var shortAsciiLogo = \x60[^\x60]*\x60;'
replacement = '''$OMNI_LOGO'''
content = re.sub(pattern, replacement, content, count=1)

with open('$CLI_JS', 'w') as f:
    f.write(content)
" 2>/dev/null || log "  ${YELLOW}!!${NC} python3 no disponible para patch de logo ASCII"

# ────────────────────────────────────────
# Patch 2: Texto ">_ Qwen Code" -> ">_ OmniCoder"
# ────────────────────────────────────────
sed -i 's/>_ Qwen Code"/>_ OmniCoder"/g' "$CLI_JS" 2>/dev/null || true

# Patch 3: System prompt
sed -i 's/You are Qwen Code/You are OmniCoder/g' "$CLI_JS" 2>/dev/null || true

# Patch 4: Session messages
sed -i 's/using Qwen Code/using OmniCoder/g' "$CLI_JS" 2>/dev/null || true
sed -i 's/this Qwen Code session/this OmniCoder session/g' "$CLI_JS" 2>/dev/null || true
sed -i 's/To continue using Qwen Code/To continue using OmniCoder/g' "$CLI_JS" 2>/dev/null || true

# Patch 5: API header
sed -i 's/"X-OpenRouter-Title": "Qwen Code"/"X-OpenRouter-Title": "OmniCoder"/g' "$CLI_JS" 2>/dev/null || true

# Verificar
if grep -q '>_ OmniCoder' "$CLI_JS" 2>/dev/null; then
    log "  ${GREEN}OK${NC} Branding parcheado: Qwen Code -> OmniCoder (logo + texto)"
else
    log "  ${YELLOW}!!${NC} Patch de branding no se aplico correctamente"
    [[ -f "${CLI_JS}.bak" ]] && cp "${CLI_JS}.bak" "$CLI_JS"
fi
