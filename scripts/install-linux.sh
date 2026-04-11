#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Instalador para Linux/macOS
# Instala Qwen Code CLI + 168 agentes + 193 skills
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║         🚀 QWEN CON PODERES - INSTALADOR           ║"
echo "║    168 Agentes + 193 Skills para Qwen Code CLI      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ──────────────────────────────────────────────────────────
# PASO 1: Verificar requisitos
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Verificando requisitos..."

# Verificar Node.js
if ! command -v node &>/dev/null; then
    echo -e "${RED}ERROR: Node.js no está instalado.${NC}"
    echo "Instálalo desde https://nodejs.org (v20 o superior)"
    echo ""
    echo "  Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs"
    echo "  Arch Linux:    sudo pacman -S nodejs npm"
    echo "  macOS:         brew install node"
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" -lt 20 ]]; then
    echo -e "${RED}ERROR: Node.js v20+ requerido. Tienes v$(node -v)${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Node.js $(node -v)"

# Verificar npm
if ! command -v npm &>/dev/null; then
    echo -e "${RED}ERROR: npm no está instalado.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} npm $(npm -v)"

# Verificar git
if ! command -v git &>/dev/null; then
    echo -e "${RED}ERROR: git no está instalado.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} git $(git --version | cut -d' ' -f3)"

# ──────────────────────────────────────────────────────────
# PASO 2: Instalar Qwen Code CLI
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[2/5]${NC} Instalando Qwen Code CLI..."

if command -v qwen &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Qwen Code ya está instalado ($(qwen --version 2>/dev/null || echo 'versión desconocida'))"
else
    echo "  Instalando @qwen-code/qwen-code..."
    npm install -g @qwen-code/qwen-code@latest
    if command -v qwen &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Qwen Code instalado correctamente"
    else
        echo -e "${YELLOW}  ⚠ npm install completado pero 'qwen' no está en PATH${NC}"
        echo "  Intenta: export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
        echo "  O reinstala con: bash -c \"\$(curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh)\" -s --source qwenchat"
    fi
fi

# ──────────────────────────────────────────────────────────
# PASO 3: Detectar directorio del repo
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[3/5]${NC} Detectando archivos del repo..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if [[ ! -d "$REPO_DIR/agents" ]] || [[ ! -d "$REPO_DIR/skills" ]]; then
    echo -e "${RED}ERROR: No se encontraron las carpetas agents/ y skills/ en $REPO_DIR${NC}"
    echo "Asegúrate de ejecutar este script desde el repo clonado."
    exit 1
fi

AGENT_COUNT=$(ls "$REPO_DIR/agents/"*.md 2>/dev/null | wc -l)
SKILL_COUNT=$(ls -d "$REPO_DIR/skills/"*/ 2>/dev/null | wc -l)
echo -e "  ${GREEN}✓${NC} Encontrados: $AGENT_COUNT agentes, $SKILL_COUNT skills"

# ──────────────────────────────────────────────────────────
# PASO 4: Instalar Agentes (SubAgents)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[4/5]${NC} Instalando agentes en ~/.qwen/agents/..."

QWEN_AGENTS_DIR="$HOME/.qwen/agents"
mkdir -p "$QWEN_AGENTS_DIR"

INSTALLED_AGENTS=0
for agent_file in "$REPO_DIR/agents/"*.md; do
    filename=$(basename "$agent_file")
    cp "$agent_file" "$QWEN_AGENTS_DIR/$filename"
    INSTALLED_AGENTS=$((INSTALLED_AGENTS + 1))
done

echo -e "  ${GREEN}✓${NC} $INSTALLED_AGENTS agentes instalados"

# ──────────────────────────────────────────────────────────
# PASO 5: Instalar Skills
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[5/5]${NC} Instalando skills en ~/.qwen/skills/..."

QWEN_SKILLS_DIR="$HOME/.qwen/skills"
mkdir -p "$QWEN_SKILLS_DIR"

INSTALLED_SKILLS=0
for skill_dir in "$REPO_DIR/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    target="$QWEN_SKILLS_DIR/$skill_name"
    # Copiar (sobreescribir si existe)
    cp -r "$skill_dir" "$target"
    INSTALLED_SKILLS=$((INSTALLED_SKILLS + 1))
done

echo -e "  ${GREEN}✓${NC} $INSTALLED_SKILLS skills instaladas"

# ──────────────────────────────────────────────────────────
# PASO 6: Copiar QWEN.md (instrucciones globales)
# ──────────────────────────────────────────────────────────
if [[ -f "$REPO_DIR/QWEN.md" ]]; then
    cp "$REPO_DIR/QWEN.md" "$HOME/.qwen/QWEN.md"
    echo -e "  ${GREEN}✓${NC} QWEN.md copiado (instrucciones globales)"
fi

# ──────────────────────────────────────────────────────────
# Resumen final
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗"
echo "║            ✅ INSTALACIÓN COMPLETADA                ║"
echo "╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Agentes instalados: ${CYAN}$INSTALLED_AGENTS${NC} → ~/.qwen/agents/"
echo -e "  Skills instaladas:  ${CYAN}$INSTALLED_SKILLS${NC} → ~/.qwen/skills/"
echo ""
echo -e "${YELLOW}Para empezar:${NC}"
echo "  1. Abre una nueva terminal"
echo "  2. Escribe: qwen"
echo "  3. Autentícate: /auth"
echo "  4. Ver agentes: /agents manage"
echo "  5. Usar skill:  /skills engineering-backend-architect"
echo ""
echo -e "${YELLOW}Categorías de agentes disponibles:${NC}"
echo "  academic (5) | design (8) | engineering (27) | game-dev (20)"
echo "  marketing (29) | paid-media (7) | product (5) | project-mgmt (6)"
echo "  sales (8) | spatial-computing (6) | specialized (30)"
echo "  support (6) | testing (8)"
echo ""
