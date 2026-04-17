#!/usr/bin/env bash
# ============================================================
# OmniCoder v4.3 - Speed Tips
# Tips para maximizar velocidad de OmniCoder
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paleta de colores compartida
if [[ -f "$SCRIPT_DIR/_colors.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/_colors.sh"
else
    CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
fi

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║        SPEED TIPS — OmniCoder v4.3                ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}${BOLD}1. Turbo Mode${NC}"
echo -e "   ${DIM}Desactiva hooks pesados, mantiene security-guard + dispatcher${NC}"
echo -e "   ${GREEN}./scripts/turbo-mode.sh on${NC}"
echo ""

echo -e "${YELLOW}${BOLD}2. Skip npx (nuevo en v4.3)${NC}"
echo -e "   ${DIM}Evita el overhead de 'npx' en hooks que invocan herramientas${NC}"
echo -e "   ${DIM}Ahorra ~200-400ms por hook que lo use${NC}"
echo -e "   ${GREEN}export OMNICODER_SKIP_NPX=1${NC}"
echo -e "   ${DIM}Agregalo a ~/.bashrc o ~/.zshrc para siempre${NC}"
echo ""

echo -e "${YELLOW}${BOLD}3. post-tool-dispatcher consolidado (v4.3)${NC}"
echo -e "   ${DIM}Ya activo por default: 6 hooks PostToolUse en uno solo${NC}"
echo -e "   ${DIM}Latencia: 340ms → 50ms (${BOLD}4.4x speedup${NC}${DIM})${NC}"
echo -e "   ${GREEN}./install-linux.sh --force${NC} ${DIM}si vienes de v4.2${NC}"
echo ""

echo -e "${YELLOW}${BOLD}4. Headless mode para tareas batch${NC}"
echo -e "   ${DIM}Sin TUI = sin overhead de renderizado${NC}"
echo -e "   ${GREEN}omnicoder -p \"tu prompt aqui\" --yolo${NC}"
echo -e "   ${GREEN}cat archivo.js | omnicoder -p \"review this\" > review.txt${NC}"
echo ""

echo -e "${YELLOW}${BOLD}5. Token caching (API key, no OAuth)${NC}"
echo -e "   ${DIM}OAuth no soporta cache. Con API key: ~90% cache hit${NC}"
echo -e "   ${DIM}Providers con mejor cache: DeepSeek (90% off), Gemini (implicito)${NC}"
echo -e "   ${GREEN}bash scripts/setup-provider.sh deepseek${NC}"
echo ""

echo -e "${YELLOW}${BOLD}6. /compress frecuentemente${NC}"
echo -e "   ${DIM}Menos contexto = respuestas mas rapidas${NC}"
echo -e "   ${GREEN}/compress${NC} ${DIM}cuando sientas que va lento${NC}"
echo ""

echo -e "${YELLOW}${BOLD}7. Prompts cortos y directos${NC}"
echo -e "   ${DIM}Malo:  'Por favor, podrias crear un archivo que...'${NC}"
echo -e "   ${DIM}Bueno: 'Crea src/auth.js con login JWT + bcrypt'${NC}"
echo ""

echo -e "${YELLOW}${BOLD}8. Una tarea a la vez (no mega-prompts)${NC}"
echo -e "   ${DIM}Malo:  '7 fases, 20 archivos, review, audit, handoff'${NC}"
echo -e "   ${DIM}Bueno: 'Crea el backend con estos 4 archivos'${NC}"
echo -e "   ${DIM}Luego: 'Ahora crea el frontend'${NC}"
echo ""

echo -e "${YELLOW}${BOLD}9. approval-mode yolo en desarrollo${NC}"
echo -e "   ${DIM}Evita pausas pidiendo permiso en cada operacion${NC}"
echo -e "   ${GREEN}/approval-mode yolo${NC}"
echo ""

echo -e "${YELLOW}${BOLD}10. Provider failover (fix en v4.3)${NC}"
echo -e "   ${DIM}Configura varios providers: si uno tira 429/503, cambia auto${NC}"
echo -e "   ${GREEN}bash scripts/setup-provider.sh nvidia${NC}  ${DIM}# primario${NC}"
echo -e "   ${GREEN}bash scripts/setup-provider.sh gemini${NC}  ${DIM}# fallback${NC}"
echo ""

echo -e "${YELLOW}${BOLD}11. Bug del scroll (workaround)${NC}"
echo -e "   ${DIM}Si no puedes scrollear hacia arriba en la terminal:${NC}"
echo -e "   ${GREEN}Opcion A:${NC} Terminal con mejor soporte (kitty, wezterm, alacritty)"
echo -e "   ${GREEN}Opcion B:${NC} Headless: omnicoder -p 'prompt' > output.txt"
echo -e "   ${GREEN}Opcion C:${NC} Shift+PgUp/PgDn"
echo -e "   ${GREEN}Opcion D:${NC} tmux con Ctrl+B+[ para modo scroll"
echo ""

echo -e "${CYAN}${BOLD}Resumen de velocidad por configuracion:${NC}"
echo ""
echo -e "  ${DIM}Config${NC}                              ${DIM}Velocidad${NC}    ${DIM}Costo${NC}"
echo -e "  ────────────────────────────────────────────────────────────"
echo -e "  OAuth + hooks full (v4.2)           Lenta        Gratis"
echo -e "  OAuth + dispatcher (v4.3)           Media        Gratis"
echo -e "  API Key (NVIDIA NIM free)           ${GREEN}Rapida${NC}       Gratis (40rpm)"
echo -e "  API Key + turbo mode + skip_npx     ${GREEN}${BOLD}Ultra${NC}        ~\$0.01/req"
echo -e "  Headless + DeepSeek (cache 90%)     ${GREEN}${BOLD}Maxima${NC}       Muy barato"
echo ""
