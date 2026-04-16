#!/usr/bin/env bash
# ============================================================
# OmniCoder v4.0 - Instalador para Linux/macOS
# 168 agentes + 193 skills + 16 hooks + 20 commands + settings
# ============================================================
set -euo pipefail

VERSION="4.0.0"

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

   ____                  _ ______          __
  / __ \____ ___  ____  (_) ____/___  ____/ /__  _____
 / / / / __ `__ \/ __ \/ / /   / __ \/ __  / _ \/ ___/
/ /_/ / / / / / / / / / / /___/ /_/ / /_/ /  __/ /
\____/_/ /_/ /_/_/ /_/_/\____/\____/\__,_/\___/_/
                                                v4.0.0

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
            echo "  --skip-cli   No instalar/actualizar OmniCoder CLI"
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
    echo -e "${BLUE}${BOLD}=== OmniCoder - Doctor ===${NC}"
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

    # Check OmniCoder CLI
    if command -v qwen &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} OmniCoder CLI instalado"
    else
        echo -e "  ${RED}!!${NC} OmniCoder CLI no encontrado"
        ISSUES=$((ISSUES + 1))
    fi

    # Check agents
    AGENT_COUNT=$(ls "$HOME/.omnicoder/agents/"*.md 2>/dev/null | wc -l || true)
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
    SKILL_COUNT=$(ls -d "$HOME/.omnicoder/skills/"*/ 2>/dev/null | wc -l || true)
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
    HOOK_COUNT=$(ls "$HOME/.omnicoder/hooks/"*.sh 2>/dev/null | wc -l || true)
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
    if [[ -d "$HOME/.omnicoder/memory" ]]; then
        MEM_COUNT=$(ls "$HOME/.omnicoder/memory/"*.md 2>/dev/null | wc -l || true)
        echo -e "  ${GREEN}OK${NC} Memoria persistente: $MEM_COUNT archivos en ~/.omnicoder/memory/"
    else
        echo -e "  ${YELLOW}!!${NC} No hay memoria persistente (reinstala para activarla)"
        ISSUES=$((ISSUES + 1))
    fi

    # Check skill index cache
    if [[ -f "$HOME/.omnicoder/.cache/skills-index.tsv" ]]; then
        IDX_COUNT=$(wc -l < "$HOME/.omnicoder/.cache/skills-index.tsv")
        echo -e "  ${GREEN}OK${NC} Indice de skills cacheado ($IDX_COUNT entradas)"
    else
        echo -e "  ${YELLOW}!!${NC} Sin indice de skills (ejecuta scripts/build-skill-index.sh)"
    fi

    # Check commands
    CMD_COUNT=$(ls "$HOME/.omnicoder/commands/"*.md 2>/dev/null | wc -l || true)
    if [[ "$CMD_COUNT" -ge 20 ]]; then
        echo -e "  ${GREEN}OK${NC} $CMD_COUNT commands instalados"
    elif [[ "$CMD_COUNT" -gt 0 ]]; then
        echo -e "  ${YELLOW}!!${NC} Solo $CMD_COUNT commands (esperado: 20+)"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${RED}!!${NC} No hay commands instalados"
        ISSUES=$((ISSUES + 1))
    fi

    # Check OMNICODER.md
    if [[ -f "$HOME/.omnicoder/OMNICODER.md" ]]; then
        echo -e "  ${GREEN}OK${NC} OMNICODER.md configurado"
    else
        echo -e "  ${RED}!!${NC} OMNICODER.md no encontrado"
        ISSUES=$((ISSUES + 1))
    fi

    # Check settings.json has hooks
    if [[ -f "$HOME/.omnicoder/settings.json" ]]; then
        if grep -q '"hooks"' "$HOME/.omnicoder/settings.json" 2>/dev/null; then
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
        echo -e "  ${GREEN}${BOLD}Todo OK - OmniCoder v4.0.0 funcionando correctamente${NC}"
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
echo -e "${BLUE}[1/11]${NC} Verificando requisitos..."

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
# PASO 2: Instalar OmniCoder CLI
# ────────���─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[2/11]${NC} OmniCoder CLI..."

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
echo -e "${BLUE}[3/11]${NC} Verificando archivos del repo..."

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
echo -e "${BLUE}[4/11]${NC} Instalando agentes..."

OMNI_AGENTS_DIR="$HOME/.omnicoder/agents"
mkdir -p "$OMNI_AGENTS_DIR"

INSTALLED=0
for f in "$REPO_DIR/agents/"*.md; do
    cp "$f" "$OMNI_AGENTS_DIR/$(basename "$f")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED agentes -> ~/.omnicoder/agents/"

# ────────────────────────────��─────────────────────────────
# PASO 5: Instalar Skills
# ────────��─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[5/11]${NC} Instalando skills..."

OMNI_SKILLS_DIR="$HOME/.omnicoder/skills"
mkdir -p "$OMNI_SKILLS_DIR"

INSTALLED=0
for d in "$REPO_DIR/skills/"*/; do
    cp -r "$d" "$OMNI_SKILLS_DIR/$(basename "$d")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED skills -> ~/.omnicoder/skills/"

# ──────────────────────────────────────────────────────────
# PASO 6: Instalar Hooks
# ───���────────────────────────────────────────────────��─────
echo ""
echo -e "${BLUE}[6/11]${NC} Instalando hooks inteligentes..."

OMNI_HOOKS_DIR="$HOME/.omnicoder/hooks"
mkdir -p "$OMNI_HOOKS_DIR"

INSTALLED=0
for f in "$REPO_DIR/hooks/"*.sh; do
    cp "$f" "$OMNI_HOOKS_DIR/$(basename "$f")"
    chmod +x "$OMNI_HOOKS_DIR/$(basename "$f")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED hooks -> ~/.omnicoder/hooks/"

# ──────────────────────────���───────────────────────────────
# PASO 7: Instalar Commands (Slash Commands)
# ──────────────────────────────────────────────────────���───
echo ""
echo -e "${BLUE}[7/11]${NC} Instalando slash commands..."

OMNI_CMDS_DIR="$HOME/.omnicoder/commands"
mkdir -p "$OMNI_CMDS_DIR"

INSTALLED=0
for f in "$REPO_DIR/commands/"*.md; do
    cp "$f" "$OMNI_CMDS_DIR/$(basename "$f")"
    INSTALLED=$((INSTALLED + 1))
done
echo -e "  ${GREEN}OK${NC} $INSTALLED commands -> ~/.omnicoder/commands/"

# ───��────────────────────────────────────────��─────────────
# PASO 8: Instalar Config (OMNICODER.md + settings.json)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[8/11]${NC} Configurando..."

# OMNICODER.md
if [[ -f "$REPO_DIR/OMNICODER.md" ]]; then
    cp "$REPO_DIR/OMNICODER.md" "$HOME/.omnicoder/OMNICODER.md"
    echo -e "  ${GREEN}OK${NC} OMNICODER.md (instrucciones globales optimizadas)"
fi

# settings.json - merge hooks si ya existe
SETTINGS_FILE="$HOME/.omnicoder/settings.json"
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
mkdir -p "$HOME/.omnicoder/logs"

# Instalar wrapper 'omnicoder' en PATH
if [[ -f "$REPO_DIR/scripts/omnicoder" ]]; then
    cp "$REPO_DIR/scripts/omnicoder" "$HOME/.omnicoder/omnicoder"
    chmod +x "$HOME/.omnicoder/omnicoder"

    # Crear symlink en ~/.local/bin (o /usr/local/bin)
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN"
    ln -sf "$HOME/.omnicoder/omnicoder" "$LOCAL_BIN/omnicoder"

    if echo "$PATH" | grep -q "$LOCAL_BIN"; then
        echo -e "  ${GREEN}OK${NC} Comando 'omnicoder' instalado en $LOCAL_BIN"
    else
        echo -e "  ${GREEN}OK${NC} Comando 'omnicoder' instalado"
        echo -e "  ${YELLOW}!!${NC} Agrega a tu PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

# ──────────────────────────────────────────────────────────
# PASO 9: Instalar memoria persistente (skeleton)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[9/11]${NC} Instalando memoria persistente..."

OMNI_MEM_DIR="$HOME/.omnicoder/memory"
mkdir -p "$OMNI_MEM_DIR"

if [[ -d "$REPO_DIR/memory" ]]; then
    for f in "$REPO_DIR/memory/"*.md; do
        [[ -f "$f" ]] || continue
        DEST="$OMNI_MEM_DIR/$(basename "$f")"
        # No sobreescribir memoria existente salvo con --force
        if [[ -f "$DEST" ]] && [[ "$FORCE" != true ]]; then
            echo -e "  ${YELLOW}!!${NC} $(basename "$f") ya existe (no sobreescrito)"
        else
            cp "$f" "$DEST"
            echo -e "  ${GREEN}OK${NC} $(basename "$f") -> ~/.omnicoder/memory/"
        fi
    done
fi

# ──────────────────────────────────────────────────────────
# PASO 10: Construir indice de skills/agentes (cache)
# ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[10/11]${NC} Construyendo indice de skills y agentes..."

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

if [[ -f "$HOME/.omnicoder/.env" ]] && [[ "$FORCE" != true ]]; then
    echo -e "  ${YELLOW}!!${NC} Ya existe ~/.omnicoder/.env (provider configurado)"
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
  ║         INSTALACION COMPLETADA v4.0.0            ║
  ╚══════════════════════════════════════════════════╝
DONE
echo -e "${NC}"

echo -e "  ${CYAN}Componentes instalados:${NC}"
echo -e "    Agentes:      ${BOLD}$(ls "$HOME/.omnicoder/agents/"*.md 2>/dev/null | wc -l)${NC} -> ~/.omnicoder/agents/"
echo -e "    Skills:       ${BOLD}$(ls -d "$HOME/.omnicoder/skills/"*/ 2>/dev/null | wc -l)${NC} -> ~/.omnicoder/skills/"
echo -e "    Hooks:        ${BOLD}$(ls "$HOME/.omnicoder/hooks/"*.sh 2>/dev/null | wc -l)${NC} -> ~/.omnicoder/hooks/"
echo -e "    Commands:     ${BOLD}$(ls "$HOME/.omnicoder/commands/"*.md 2>/dev/null | wc -l)${NC} -> ~/.omnicoder/commands/"
echo -e "    Config:       ${BOLD}OMNICODER.md + settings.json${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}Para empezar:${NC}"
echo -e "    ${BOLD}qwen${NC}                          # Iniciar OmniCoder"
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
if [[ -f "$HOME/.omnicoder/.env" ]]; then
    grep "^OPENAI_MODEL=" "$HOME/.omnicoder/.env" 2>/dev/null | sed 's/^/    /'
else
    echo -e "    ${RED}(no configurado)${NC} -> bash scripts/setup-provider.sh"
fi
echo ""
echo -e "  ${CYAN}Diagnostico:${NC} ${BOLD}./scripts/install-linux.sh --doctor${NC}"
echo -e "  ${CYAN}Cambiar provider:${NC} ${BOLD}./scripts/switch-provider.sh nvidia|gemini|minimax|...${NC}"
echo ""
