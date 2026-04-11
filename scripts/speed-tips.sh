#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Speed Tips
# Muestra tips para maximizar velocidad de Qwen Code
# ============================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║     SPEED TIPS - Qwen Con Poderes v2            ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}${BOLD}1. Usar Turbo Mode${NC}"
echo -e "   ${DIM}Desactiva hooks pesados, solo mantiene security-guard${NC}"
echo -e "   ${GREEN}./scripts/turbo-mode.sh on${NC}"
echo ""

echo -e "${YELLOW}${BOLD}2. Usar modelo local con Ollama (0 latencia de red)${NC}"
echo -e "   ${DIM}Respuestas en 1-5 segundos en vez de 10-30${NC}"
echo -e "   ${GREEN}curl -fsSL https://ollama.com/install.sh | sh${NC}"
echo -e "   ${GREEN}ollama pull qwen2.5-coder:7b${NC}"
echo -e "   ${DIM}Luego: /model dentro de Qwen Code para seleccionar${NC}"
echo ""

echo -e "${YELLOW}${BOLD}3. Usar headless mode para tareas batch${NC}"
echo -e "   ${DIM}Sin UI = sin overhead de renderizado de terminal${NC}"
echo -e "   ${GREEN}qwen -p \"tu prompt aqui\" --yolo${NC}"
echo -e "   ${GREEN}cat archivo.js | qwen -p \"review this\" > review.txt${NC}"
echo ""

echo -e "${YELLOW}${BOLD}4. Activar token caching (API key, no OAuth)${NC}"
echo -e "   ${DIM}OAuth no soporta cache. Con API key: ~90% cache hit${NC}"
echo -e "   ${DIM}Obtener API key: https://bailian.console.aliyun.com/${NC}"
echo -e "   ${GREEN}/auth -> Alibaba Cloud Coding Plan -> tu API key${NC}"
echo ""

echo -e "${YELLOW}${BOLD}5. Usar /compress frecuentemente${NC}"
echo -e "   ${DIM}Menos contexto = respuestas mas rapidas${NC}"
echo -e "   ${GREEN}/compress${NC} ${DIM}cuando sientas que va lento${NC}"
echo ""

echo -e "${YELLOW}${BOLD}6. Prompts cortos y directos${NC}"
echo -e "   ${DIM}Malo:  'Por favor, podrias crear un archivo que...'${NC}"
echo -e "   ${DIM}Bueno: 'Crea src/auth.js con login JWT + bcrypt'${NC}"
echo ""

echo -e "${YELLOW}${BOLD}7. Una tarea a la vez (no mega-prompts)${NC}"
echo -e "   ${DIM}Malo:  '7 fases, 20 archivos, review, audit, handoff'${NC}"
echo -e "   ${DIM}Bueno: 'Crea el backend con estos 4 archivos'${NC}"
echo -e "   ${DIM}Luego: 'Ahora crea el frontend'${NC}"
echo ""

echo -e "${YELLOW}${BOLD}8. approval-mode yolo para desarrollo${NC}"
echo -e "   ${DIM}Evita pausas pidiendo permiso en cada operacion${NC}"
echo -e "   ${GREEN}/approval-mode yolo${NC}"
echo ""

echo -e "${YELLOW}${BOLD}9. Bug del scroll (workaround)${NC}"
echo -e "   ${DIM}Si no puedes scrollear hacia arriba en la terminal:${NC}"
echo -e "   ${GREEN}Opcion A:${NC} Usa terminal con mejor soporte (kitty, wezterm, alacritty)"
echo -e "   ${GREEN}Opcion B:${NC} Usa headless mode: qwen -p 'prompt' > output.txt"
echo -e "   ${GREEN}Opcion C:${NC} Usa Shift+PgUp/PgDn en vez de scroll con mouse"
echo -e "   ${GREEN}Opcion D:${NC} Usa tmux con Ctrl+B+[ para modo scroll"
echo ""

echo -e "${YELLOW}${BOLD}10. Modelo rapido para sugerencias${NC}"
echo -e "   ${DIM}Configura un modelo ligero para followup suggestions${NC}"
echo -e "   ${GREEN}/model --fast qwen3-coder-flash${NC}"
echo ""

echo -e "${CYAN}${BOLD}Resumen de velocidad por configuracion:${NC}"
echo ""
echo -e "  ${DIM}Config${NC}                   ${DIM}Velocidad${NC}    ${DIM}Costo${NC}"
echo -e "  ──────────────────────────────────────────────"
echo -e "  OAuth + hooks full      Lenta       Gratis"
echo -e "  OAuth + turbo mode      Media       Gratis"
echo -e "  API Key + turbo mode    ${GREEN}Rapida${NC}      ~\$0.01/req"
echo -e "  Ollama local + turbo    ${GREEN}${BOLD}Ultra${NC}       Gratis"
echo -e "  Headless + Ollama       ${GREEN}${BOLD}Maxima${NC}      Gratis"
echo ""
