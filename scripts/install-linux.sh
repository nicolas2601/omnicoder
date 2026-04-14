#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes v3.5 - Instalador para Linux/macOS
# 168 agentes + 193 skills + 16 hooks + 20 commands + settings
# ============================================================
set -euo pipefail

VERSION="3.5.1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ──────────────────────────────────────────────────────────
# Banner
# ──────────────────────────���───────────────────────────────
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'

   ___                          ____              ____            __
  / _ \__    _____  ____       / ___|___  _ __   |  _ \ ___   __| | ___ _ __ ___  ___
 | | | \ \ /\ / / _ \ '_ \    | |   / _ \| '_ \  | |_) / _ \ / _` |/ _ \ '__/ _ \/ __|
 | |_| |\ V  V /  __/ | | |   | |__| (_) | | | | |  __/ (_) | (_| |  __/ | |  __/\__ \
  \__\_\ \_/\_/ \___|_| |_|    \____\___/|_| |_| |_|   \___/ \__,_|\___|_|  \___||___/
                                                                               v3.5.1

BANNER
echo -e "${NC}"
echo -e "${DIM}  168 Agentes + 193 Skills + 16 Hooks + 20 Commands${NC}"
echo -e "${DIM}  Multi-provider | Cognitive routing | Subagent verification${NC}"
echo ""

# ──────────────────────────────────────────────────────────
# Detectar directorio del repo
# ─��─────────────────────���──────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ���─────────────────────────────────────────────────────────
# Flags
# ─────────────────────��────────────────────────────────────
SKIP_CLI=false
FORCE=false
DOCTOR_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --skip-cli) SKIP_CLI=true ;;
        --force) FORCE=true ;;
        --doctor) DOCTOR_ONLY=true ;;
        --help|-h)
            echo "Uso: ./install-linux.sh [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --skip-cli   No instalar/actualizar Qwen Code CLI"
            echo "  --force      Sobreescribir todo sin preguntar"
            echo "  --doctor     Solo ejecutar diagnostico (no instalar)"
            echo "  --help       Mostrar esta ayuda"
            exit 0
            ;;
    esac
done

# ───��──────────────────────────────────��───────────────────
# Doctor mode
# ─────────────────────��────────────────────────────────────
doctor() {
    echo -e "${BLUE}${BOLD}=== Qwen Con Poderes - Doctor ===${NC}"
    echo ""
    ISSUES=0

    # Check Node.js
    if command -v node &>/dev/null; then
        NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
        if [[ "$NODE_VER" -ge 20 ]]; then
            echo -e "  ${GREEN}OK${NC} Node.js $(node -v)"
        else
            echo -e "  ${RED}!!${NC} Node.js $(node -v) - necesita v20+"
            ISSUES=$((ISSUES + 1))
        fi
    else
        echo -e "  ${RED}!!${NC} Node.js no instalado"
        ISSUES=$((ISSUES + 1))
    fi

    # Check Qwen CLI
    if command -v qwen &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} Qwen Code CLI instalado"
    else
        echo -e "  ${RED}!!${NC} Qwen Code CLI no encontrado"
        ISSUES=$((ISSUES + 1))
    fi

    # Check agents
    AGENT_COUNT=$(ls "$HOME/.qwen/agents/"*.md 2>/dev/null | wc -l || echo 0)
    if [[ "$AGENT_COUNT" -gt 100 ]]; then
        echo -e "  ${GREEN}OK${NC} $AGENT_COUNT agentes instalados"
    elif [[ "$AGENT_COUNT" -gt 0 ]]; then
        echo -e "  ${YELLOW}!!${NC} Solo $AGENT_COUNT agentes (esperado: 168+)"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${RED}!!${NC} No hay agentes instalados"
        ISSUES=$((ISSUES + 1))
    fi

    # Check skills
    SKILL_COUNT=$(ls -d "$HOME/.qwen/skills/"*/ 2>/dev/null | wc -l || echo 0)
    if [[ "$SKILL_COUNT" -gt 150 ]]; then
        echo -e "  ${GREEN}OK${NC} $SKILL_COUNT skills instaladas"
    elif [[ "$SKILL_COUNT" -gt 0 ]]; then
        echo -e "  ${YELLOW}!!${NC} Solo $SKILL_COUNT skills (esperado: 193+)"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${RED}!!${NC} No hay skills instaladas"
        ISSUES=$((ISSUES + 1))
    fi

    # Check hooks
    HOOK_COUNT=$(ls "$HOME/.qwen/hooks/"*.sh 2>/dev/null | wc -l || echo 0)
    if [[ "$HOOK_COUNT" -ge 16 ]]; then
        echo -e "  ${GREEN}OK${NC} $HOOK_COUNT hooks instalados (v3.5 con subagent-verify + error-recover)"
    elif [[ "$HOOK_COUNT" -gt 0 ]]; then
        echo -e "  ${YELLOW}!!${NC} Solo $HOOK_COUNT hooks (esperado: 16+)"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${RED}!!${NC} No hay hooks instalados"
        ISSUES=$((ISSUES + 1))
    fi

    # Check memory
    if [[ -d "$HOME/.qwen/memory" ]]; then
        MEM_COUNT=$(ls "$HOME/.qwen/memory/"*.md 2>/dev/null | wc -l || echo 0)
        echo -e "  ${GREEN}OK${NC} Memoria persistente: $MEM_COUNT archivos en ~/.qwen/memory/"
    else
        echo -e "  ${YELLOW}!!${NC} No hay memoria persistente (reinstala para activarla)"
        ISSUES=$((ISSUES + 1))
    fi

    # Check skill index cache
    if [[ -f "$HOME/.qwen/.cache/skills-index.tsv" ]]; then
        IDX_COUNT=$(wc -l < "$HOME/.qwen/.cache/skills-index.tsv")
        echo -e "  ${GREEN}OK${NC} Indice de skills cacheado ($IDX_COUNT entradas)"
    else
        echo -e "  ${YELLOW}!!${NC} Sin indice de skills (ejecuta scripts/build-skill-index.sh)"
    fi

    # Check commands
    CMD_COUNT=$(ls "$HOME/.qwen/commands/"*.md 2>/dev/null | wc -l || echo 0)
    if [[ "$CMD_COUNT" -ge 20 ]]; then
        echo -e "  ${GREEN}OK${NC} $CMD_COUNT commands instalados"
    elif [[ "$CMD_COUNT" -gt 0 ]]; then
        echo -e "  ${YELLOW}!!${NC} Solo $CMD_COUNT commands (esperado: 20+)"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${RED}!!${NC} No hay commands instalados"
        ISSUES=$((ISSUES + 1))
    fi

    # Check QWEN.md
    if [[ -f "$HOME/.qwen/QWEN.md" ]]; then
        echo -e "  ${GREEN}OK${NC} QWEN.md configurado"
    else
        echo -e "  ${RED}!!${NC} QWEN.md no encontrado"
        ISSUES=$((ISSUES + 1))
    fi

    # Check settings.json has hooks
    if [[ -f "$HOME/.qwen/settings.json" ]]; then
        if grep -q '"hooks"' "$HOME/.qwen/settings.json" 2>/dev/null; then
            echo -e "  ${GREEN}OK${NC} settings.json con hooks configurados"
        else
            echo -e "  ${YELLOW}!!${NC} settings.json sin hooks"
            ISSUES=$((ISSUES + 1))
        fi
    else
        echo -e "  ${YELLOW}!!${NC} settings.json no encontrado"
        ISSUES=$((ISSUES + 1))
    fi

    # Check jq (requerido para hooks)
    if command -v jq &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} jq instalado (requerido para hooks)"
    else
        echo -e "  ${YELLOW}!!${NC} jq no instalado - los hooks no funcionaran"
        echo -e "       ${DIM}Instala: sudo pacman -S jq / sudo apt install jq / brew install jq${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    echo ""
    if [[ "$ISSUES" -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}Todo OK - Qwen Con Poderes v3.5.1 funcionando correctamente${NC}"
    else
        echo -e "  ${YELLOW}${BOLD}$ISSUES issues encontrados${NC}"
        echo -e "  ${DIM}Ejecuta: ./install-linux.sh --force para reparar${NC}"
    fi
    echo ""
}

if [[ "$DOCTOR_ONLY" == true ]]; then
    doctor
    exit 0
fi

# ──────────────────────────────────────────────────────────
# PASO 1: Verificar requisitos
# ───────────────────────────────────────────────��──────────
echo -e "${BLUE}[1/8]${NC} Verificando requisitos..."

# Node.js
if ! command -v node &>/dev/null; then
    echo -e "${RED}ERROR: Node.js no esta instalado.${NC}"
    echo ""
    echo "  Arch Linux:    sudo pacman -S nodejs npm"
    echo "  Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs"
    echo "  macOS:         brew install node"
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" -lt 20 ]]; then
    echo -e "${RED}ERROR: Node.js v20+ requerido. Tienes v$(node -v)${NC}"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} Node.js $(node -v)"

# npm
if ! command -v npm &>/dev/null; then
    echo -e "${RED}ERROR: npm no esta instalado.${NC}"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} npm $(npm -v)"

# git
if ! command -v git &>/dev/null; then
    echo -e "${RED}ERROR: git no esta instalado.${NC}"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} git $(git --version | cut -d' ' -f3)"

# jq (warning, no bloqueante)
if ! command -v jq &>/dev/null; then
    echo -e "  ${YELLOW}!!${NC} jq no instalado - los hooks no funcionaran"
    echo -e "     ${DIM}Recomendado: sudo pacman -S jq / sudo apt install jq / brew install jq${NC}"
else
    echo -e "  ${GREEN}OK${NC} jq $(jq --version 2>/dev/null | sed 's/jq-//')"
fi

# ───��───────────────────────────��──────────────────────────
# PASO 2: Instalar Qwen Code CLI
# ────────���─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[2/8]${NC} Qwen Code CLI..."

if [[ "$SKIP_CLI" == true ]]; then
    echo -e "  ${DIM}Saltado (--skip-cli)${NC}"
elif command -v qwen &>/dev/null; then
    echo -e "  ${GREEN}OK${NC} Ya instalado"
else
    echo "  Instalando @qwen-code/qwen-code..."
    npm install -g @qwen-code/qwen-code@latest
    if command -v qwen &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} Instalado correctamente"
    else
        echo -e "${YELLOW}  !! npm install OK pero 'qwen' no esta en PATH${NC}"
        echo "  Intenta: export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
    fi
fi

# ─────────────���────────────────────────────��───────────────
# PASO 3: Verificar repo
# ───���────────────────────────��────────────────────────���────
echo ""
echo -e "${BLUE}[3/8]${NC} Verificando archivos del repo..."

if [[ ! -d "$REPO_DIR/agents" ]] || [[ ! -d "$REPO_DIR/skills" ]]; then
    echo -e "${RED}ERROR: No se encontraron agents/ y skills/ en $REPO_DIR${NC}"
    exit 1
fi

AGENT_COUNT=$(ls "$REPO_DIR/agents/"*.md 2>/dev/null | wc -l)
SKILL_COUNT=$(ls -d "$REPO_DIR/skills/"*/ 2>/dev/null | wc -l)
HOOK_COUNT=$(ls "$REPO_DIR/hooks/"*.sh 2>/dev/null | wc -l)
CMD_COUNT=$(ls "$REPO_DIR/commands/"*.md 2>/dev/null | wc -l)
echo -e "  ${GREEN}OK${NC} $AGENT_COUNT agentes, $SKILL_COUNT skills, $HOOK_COUNT hooks, $CMD_COUNT commands"

# ────��──────────────────────────────────────────────────��──
# PASO 4: Instalar Agentes
# ────────────────────��─────────────────────────────────────
echo ""
echo -e "${BLUE}[4/8]${NC} Instalando agentes..."

QWEN_AGENTS_DIR="$HOME/.qwen/agents"
mkdir -p "$QWEN_AGENTS_DIR"

INSTALLED=0
for f in "$REPO_DIR/agents/"*.md; do
    cp "$f" "$QWEN_AGENTS_DIR/$(basename "$f")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED agentes -> ~/.qwen/agents/"

# ────────────────────────────��─────────────────────────────
# PASO 5: Instalar Skills
# ────────��─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[5/8]${NC} Instalando skills..."

QWEN_SKILLS_DIR="$HOME/.qwen/skills"
mkdir -p "$QWEN_SKILLS_DIR"

INSTALLED=0
for d in "$REPO_DIR/skills/"*/; do
    cp -r "$d" "$QWEN_SKILLS_DIR/$(basename "$d")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED skills -> ~/.qwen/skills/"

# ──────────────────────────────────────────────────────────
# PASO 6: Instalar Hooks
# ───���────────────────────────────────────────────────��─────
echo ""
echo -e "${BLUE}[6/8]${NC} Instalando hooks inteligentes..."

QWEN_HOOKS_DIR="$HOME/.qwen/hooks"
mkdir -p "$QWEN_HOOKS_DIR"

INSTALLED=0
for f in "$REPO_DIR/hooks/"*.sh; do
    cp "$f" "$QWEN_HOOKS_DIR/$(basename "$f")"
    chmod +x "$QWEN_HOOKS_DIR/$(basename "$f")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED hooks -> ~/.qwen/hooks/"

# ──────────────────────────���───────────────────────────────
# PASO 7: Instalar Commands (Slash Commands)
# ──────────────────────────────────────────────────────���───
echo ""
echo -e "${BLUE}[7/8]${NC} Instalando slash commands..."

QWEN_CMDS_DIR="$HOME/.qwen/commands"
mkdir -p "$QWEN_CMDS_DIR"

INSTALLED=0
for f in "$REPO_DIR/commands/"*.md; do
    cp "$f" "$QWEN_CMDS_DIR/$(basename "$f")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED commands -> ~/.qwen/commands/"

# ───��────────────────────────────────────────��─────────────
# PASO 8: Instalar Config (QWEN.md + settings.json)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[8/8]${NC} Configurando..."

# QWEN.md
if [[ -f "$REPO_DIR/QWEN.md" ]]; then
    cp "$REPO_DIR/QWEN.md" "$HOME/.qwen/QWEN.md"
    echo -e "  ${GREEN}OK${NC} QWEN.md (instrucciones globales optimizadas)"
fi

# settings.json - merge hooks si ya existe
SETTINGS_FILE="$HOME/.qwen/settings.json"
if [[ -f "$SETTINGS_FILE" ]] && [[ "$FORCE" != true ]]; then
    # Verificar si ya tiene hooks
    if grep -q '"hooks"' "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "  ${YELLOW}!!${NC} settings.json ya tiene hooks configurados (no sobreescrito)"
        echo -e "     ${DIM}Usa --force para sobreescribir${NC}"
    else
        # Merge: agregar hooks al settings existente
        if command -v jq &>/dev/null; then
            HOOKS_JSON=$(jq '.hooks' "$REPO_DIR/config/settings.json")
            jq --argjson hooks "$HOOKS_JSON" '. + {hooks: $hooks}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo -e "  ${GREEN}OK${NC} Hooks agregados a settings.json existente"
        else
            echo -e "  ${YELLOW}!!${NC} jq no disponible - no se pudieron agregar hooks a settings.json"
        fi
    fi
else
    cp "$REPO_DIR/config/settings.json" "$SETTINGS_FILE"
    echo -e "  ${GREEN}OK${NC} settings.json con hooks pre-configurados"
fi

# Crear directorio de logs
mkdir -p "$HOME/.qwen/logs"

# ──────────────────────────────────────────────────────────
# PASO 9: Instalar memoria persistente (skeleton)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[9/10]${NC} Instalando memoria persistente..."

QWEN_MEM_DIR="$HOME/.qwen/memory"
mkdir -p "$QWEN_MEM_DIR"

if [[ -d "$REPO_DIR/memory" ]]; then
    for f in "$REPO_DIR/memory/"*.md; do
        [[ -f "$f" ]] || continue
        DEST="$QWEN_MEM_DIR/$(basename "$f")"
        # No sobreescribir memoria existente salvo con --force
        if [[ -f "$DEST" ]] && [[ "$FORCE" != true ]]; then
            echo -e "  ${YELLOW}!!${NC} $(basename "$f") ya existe (no sobreescrito)"
        else
            cp "$f" "$DEST"
            echo -e "  ${GREEN}OK${NC} $(basename "$f") -> ~/.qwen/memory/"
        fi
    done
fi

# ──────────────────────────────────────────────────────────
# PASO 10: Construir indice de skills/agentes (cache)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[10/10]${NC} Construyendo indice de skills y agentes..."

if [[ -x "$REPO_DIR/scripts/build-skill-index.sh" ]]; then
    bash "$REPO_DIR/scripts/build-skill-index.sh" || true
else
    chmod +x "$REPO_DIR/scripts/build-skill-index.sh" 2>/dev/null || true
    bash "$REPO_DIR/scripts/build-skill-index.sh" || true
fi

# ──────────────────────────────────────────────────────────
# PASO 11: Setup interactivo de provider (API key)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[11/11]${NC} Setup de provider (API key)..."

if [[ -f "$HOME/.qwen/.env" ]] && [[ "$FORCE" != true ]]; then
    echo -e "  ${YELLOW}!!${NC} Ya existe ~/.qwen/.env (provider configurado)"
    echo -e "     ${DIM}Para cambiar: bash scripts/setup-provider.sh${NC}"
else
    echo ""
    read -rp "  Configurar API key ahora? [Y/n]: " setup_now
    if [[ "${setup_now,,}" != "n" ]]; then
        if [[ -x "$REPO_DIR/scripts/setup-provider.sh" ]]; then
            bash "$REPO_DIR/scripts/setup-provider.sh"
        else
            chmod +x "$REPO_DIR/scripts/setup-provider.sh" 2>/dev/null || true
            bash "$REPO_DIR/scripts/setup-provider.sh"
        fi
    else
        echo -e "  ${DIM}Saltado. Cuando quieras: bash scripts/setup-provider.sh${NC}"
    fi
fi

# ──────────────────────────────────────────────────────────
# Resumen
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
cat << 'DONE'
  ╔══════════════════════════════════════════════════╗
  ║         INSTALACION COMPLETADA v3.5.1            ║
  ╚══════════════════════════════════════════════════╝
DONE
echo -e "${NC}"

echo -e "  ${CYAN}Componentes instalados:${NC}"
echo -e "    Agentes:      ${BOLD}$(ls "$HOME/.qwen/agents/"*.md 2>/dev/null | wc -l)${NC} -> ~/.qwen/agents/"
echo -e "    Skills:       ${BOLD}$(ls -d "$HOME/.qwen/skills/"*/ 2>/dev/null | wc -l)${NC} -> ~/.qwen/skills/"
echo -e "    Hooks:        ${BOLD}$(ls "$HOME/.qwen/hooks/"*.sh 2>/dev/null | wc -l)${NC} -> ~/.qwen/hooks/"
echo -e "    Commands:     ${BOLD}$(ls "$HOME/.qwen/commands/"*.md 2>/dev/null | wc -l)${NC} -> ~/.qwen/commands/"
echo -e "    Config:       ${BOLD}QWEN.md + settings.json${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}Para empezar:${NC}"
echo -e "    ${BOLD}qwen${NC}                          # Iniciar Qwen Code"
echo -e "    ${BOLD}/agents manage${NC}                 # Ver agentes disponibles"
echo -e "    ${BOLD}/skills${NC}                        # Ver skills disponibles"
echo -e "    ${BOLD}/review${NC}                        # Code review del diff actual"
echo -e "    ${BOLD}/ship${NC}                          # Pipeline completo: test+lint+commit+push"
echo -e "    ${BOLD}/audit${NC}                         # Auditoria de seguridad y calidad"
echo -e "    ${BOLD}/handoff${NC}                       # Guardar progreso entre sesiones"
echo -e "    ${BOLD}/verify-last${NC}                   # Auditoria del ultimo subagent"
echo ""
echo -e "  ${YELLOW}${BOLD}Hooks activos (16 total):${NC}"
echo -e "    ${DIM}security-guard${NC}          Bloquea comandos peligrosos y secrets"
echo -e "    ${DIM}pre-edit-guard${NC}          Protege archivos sensibles (.env, keys)"
echo -e "    ${DIM}skill-router${NC}            Routing cognitivo (BM25 + project context)"
echo -e "    ${DIM}session-init${NC}            Carga handoff de sesion anterior"
echo -e "    ${DIM}auto-handoff${NC}            Sugiere guardar progreso al terminar"
echo -e "    ${DIM}post-tool-logger${NC}        Registra operaciones para auditoria"
echo -e "    ${DIM}notify-desktop${NC}          Notificaciones nativas del OS"
echo -e "    ${DIM}subagent-inject${NC}         Inyecta contrato de evidencia a subagents"
echo -e "    ${DIM}subagent-verify${NC}         Verifica que subagents completaron tarea"
echo -e "    ${DIM}subagent-error-recover${NC}  Detecta errores 400 en subagents"
echo -e "    ${DIM}+ 6 hooks de aprendizaje (trajectories/learned/patterns/...)${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}Provider activo:${NC}"
if [[ -f "$HOME/.qwen/.env" ]]; then
    grep "^OPENAI_MODEL=" "$HOME/.qwen/.env" 2>/dev/null | sed 's/^/    /'
else
    echo -e "    ${RED}(no configurado)${NC} -> bash scripts/setup-provider.sh"
fi
echo ""
echo -e "  ${CYAN}Diagnostico:${NC} ${BOLD}./scripts/install-linux.sh --doctor${NC}"
echo -e "  ${CYAN}Cambiar provider:${NC} ${BOLD}./scripts/switch-provider.sh nvidia|gemini|minimax|...${NC}"
echo ""
