#!/usr/bin/env bash
# ============================================================
# OmniCoder - Turbo Mode Toggle
# Alterna entre settings normal (todos los hooks) y turbo
# (solo security-guard, maxima velocidad)
# ============================================================
set -euo pipefail

SETTINGS="$HOME/.omnicoder/settings.json"
SETTINGS_FULL="$HOME/.omnicoder/settings-full.json"
SETTINGS_TURBO="$HOME/.omnicoder/settings-turbo.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Paleta compartida
if [[ -f "$SCRIPT_DIR/_colors.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/_colors.sh"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; NC='\033[0m'
fi

case "${1:-toggle}" in
    on|turbo)
        # Guardar settings actual como backup
        if [[ -f "$SETTINGS" ]]; then
            cp "$SETTINGS" "$SETTINGS_FULL"
        fi
        # Copiar settings turbo
        cp "$REPO_DIR/config/settings-turbo.json" "$SETTINGS"
        echo -e "${GREEN}TURBO MODE ON${NC}"
        echo -e "  Hooks activos: solo ${CYAN}security-guard${NC} + ${CYAN}notify-desktop${NC}"
        echo -e "  Approval: ${YELLOW}yolo${NC} (auto-approve todo)"
        echo -e "  Cache: ${GREEN}habilitado${NC}"
        echo -e "  Temperature: ${GREEN}0.2${NC} (respuestas mas directas)"
        echo ""
        echo -e "  ${YELLOW}Reinicia OmniCoder para aplicar cambios${NC}"
        echo -e "  Restaurar: $0 off"
        ;;
    off|normal)
        if [[ -f "$SETTINGS_FULL" ]]; then
            cp "$SETTINGS_FULL" "$SETTINGS"
            echo -e "${GREEN}NORMAL MODE${NC} - Todos los hooks restaurados"
        else
            cp "$REPO_DIR/config/settings.json" "$SETTINGS"
            echo -e "${GREEN}NORMAL MODE${NC} - Settings por defecto restaurado"
        fi
        echo -e "  ${YELLOW}Reinicia OmniCoder para aplicar cambios${NC}"
        ;;
    status)
        if [[ -f "$SETTINGS" ]]; then
            HOOK_COUNT=$(grep -o '"hooks"' "$SETTINGS" | wc -l)
            if grep -q '"yolo"' "$SETTINGS" 2>/dev/null; then
                echo -e "Modo actual: ${YELLOW}TURBO${NC}"
            else
                echo -e "Modo actual: ${GREEN}NORMAL${NC}"
            fi
        else
            echo -e "Modo actual: ${RED}SIN CONFIG${NC}"
        fi
        ;;
    *)
        echo "Uso: $0 [on|off|status]"
        echo ""
        echo "  on/turbo   - Activa turbo mode (menos hooks, mas rapido)"
        echo "  off/normal - Restaura modo normal (todos los hooks)"
        echo "  status     - Muestra modo actual"
        ;;
esac
