#!/usr/bin/env bash
# ============================================================
# OmniCoder - Patch Branding
# Reemplaza "Qwen Code" por "OmniCoder" en la TUI del CLI
# Se ejecuta automaticamente durante la instalacion.
# Seguro: solo modifica strings de display, no logica.
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detectar ubicacion del CLI
CLI_JS=""
if command -v qwen &>/dev/null; then
    QWEN_PATH=$(which qwen)
    # Resolve symlink
    REAL_PATH=$(readlink -f "$QWEN_PATH" 2>/dev/null || echo "$QWEN_PATH")
    CLI_DIR=$(dirname "$REAL_PATH")
    # Check common locations
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
    echo -e "  ${YELLOW}!!${NC} No se encontro cli.js de Qwen Code. Patch de branding saltado."
    echo -e "     ${YELLOW}Esto es normal si qwen no esta instalado aun.${NC}"
    exit 0
fi

# Verificar si ya esta parcheado
if grep -q '>_ OmniCoder' "$CLI_JS" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} Branding ya parcheado (OmniCoder)"
    exit 0
fi

# Backup
cp "$CLI_JS" "${CLI_JS}.bak" 2>/dev/null || true

# Patch 1: TUI header ">_ Qwen Code" -> ">_ OmniCoder"
sed -i 's/>_ Qwen Code"/>_ OmniCoder"/g' "$CLI_JS"

# Patch 2: System prompt "You are Qwen Code" -> "You are OmniCoder"
sed -i 's/You are Qwen Code/You are OmniCoder/g' "$CLI_JS"

# Patch 3: Session messages
sed -i 's/using Qwen Code/using OmniCoder/g' "$CLI_JS"
sed -i 's/this Qwen Code session/this OmniCoder session/g' "$CLI_JS"
sed -i 's/To continue using Qwen Code/To continue using OmniCoder/g' "$CLI_JS"

# Patch 4: Title for API calls (optional, cosmetic)
sed -i 's/"X-OpenRouter-Title": "Qwen Code"/"X-OpenRouter-Title": "OmniCoder"/g' "$CLI_JS"

# Verificar
if grep -q '>_ OmniCoder' "$CLI_JS" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} Branding parcheado: Qwen Code -> OmniCoder"
else
    echo -e "  ${YELLOW}!!${NC} Patch de branding no se aplico correctamente"
    # Restaurar backup
    [[ -f "${CLI_JS}.bak" ]] && cp "${CLI_JS}.bak" "$CLI_JS"
fi
