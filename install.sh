#!/usr/bin/env bash
# ============================================================
# OmniCoder - One-liner installer (curl-able)
# ============================================================
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --force
# ============================================================
set -euo pipefail

# ──────────────────────────────────────────────────────────
# Configuración del repo
# ──────────────────────────────────────────────────────────
REPO_URL="${OMNICODER_REPO_URL:-https://github.com/nicolas2601/omnicoder.git}"
SRC_DIR="${OMNICODER_SRC_DIR:-$HOME/.omnicoder-src}"
RUNTIME_DIR="$HOME/.omnicoder"

# ──────────────────────────────────────────────────────────
# Colores ANSI (TTY fallback)
# ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# TTY detection para modo interactivo
INTERACTIVE=false
[[ -t 0 ]] && [[ -t 1 ]] && INTERACTIVE=true

err()  { echo -e "${RED}ERROR:${NC} $*" >&2; }
warn() { echo -e "${YELLOW}!!${NC} $*"; }
ok()   { echo -e "${GREEN}OK${NC} $*"; }
step() { echo -e "${BLUE}==>${NC} ${BOLD}$*${NC}"; }

trap 'err "Instalación interrumpida (línea $LINENO)"; exit 1' ERR

show_help() {
    cat <<EOF
${BOLD}OmniCoder installer${NC}

${BOLD}Uso:${NC}
  curl -fsSL <install.sh> | bash
  curl -fsSL <install.sh> | bash -s -- [flags]

${BOLD}Flags (pasan al install-linux.sh):${NC}
  --skip-cli       No instalar/actualizar el CLI de OmniCoder
  --force          Sobreescribir todo sin preguntar
  --update         Actualizar a la versión más reciente
  --doctor         Solo ejecutar diagnóstico
  --help, -h       Muestra esta ayuda

${BOLD}Variables de entorno:${NC}
  OMNICODER_REPO_URL   URL del repo (default: $REPO_URL)
  OMNICODER_SRC_DIR    Dir fuente local (default: $SRC_DIR)
EOF
}

# ──────────────────────────────────────────────────────────
# Parse flags
# ──────────────────────────────────────────────────────────
PASSTHROUGH=()
for arg in "$@"; do
    case "$arg" in
        --help|-h) show_help; exit 0 ;;
        *) PASSTHROUGH+=("$arg") ;;
    esac
done

# Si no es TTY y no hay --force/--yes, asumir non-interactive
if ! $INTERACTIVE; then
    if ! printf '%s\n' "${PASSTHROUGH[@]:-}" | grep -qE -- '--force|--update|--yes'; then
        # añadir --force por defecto en modo pipe para evitar prompts bloqueantes
        :  # install-linux.sh maneja prompts; el wrapper no fuerza
    fi
fi

# ──────────────────────────────────────────────────────────
# Banner
# ──────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
cat <<'BANNER'
  ____                  _ ______          __
 / __ \____ ___  ____  (_) ____/___  ____/ /__  _____
/ / / / __ `__ \/ __ \/ / /   / __ \/ __  / _ \/ ___/
/_/ / / / / / / / / / / / /___/ /_/ / /_/ /  __/ /
\____/_/ /_/ /_/_/ /_/_/\____/\____/\__,_/\___/_/
                                    one-liner installer
BANNER
echo -e "${NC}"

# ──────────────────────────────────────────────────────────
# PASO 1: Detectar OS
# ──────────────────────────────────────────────────────────
step "[1/6] Detectando sistema operativo"
OS="$(uname -s 2>/dev/null || echo Unknown)"
case "$OS" in
    Linux)  ok "Linux detectado" ;;
    Darwin) ok "macOS detectado" ;;
    *)
        err "Sistema no soportado: $OS (solo Linux y macOS)"
        exit 1 ;;
esac

# Detectar distro para mensajes de ayuda
PKG_HINT=""
if [[ -f /etc/arch-release ]]; then
    PKG_HINT="sudo pacman -S %s"
elif [[ -f /etc/debian_version ]]; then
    PKG_HINT="sudo apt install %s"
elif [[ -f /etc/redhat-release ]]; then
    PKG_HINT="sudo dnf install %s"
elif [[ "$OS" == "Darwin" ]]; then
    PKG_HINT="brew install %s"
else
    PKG_HINT="<tu gestor de paquetes> install %s"
fi

# ──────────────────────────────────────────────────────────
# PASO 2: Verificar prerequisitos
# ──────────────────────────────────────────────────────────
step "[2/6] Verificando prerequisitos"
MISSING=()

check_cmd() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        warn "$cmd no instalado"
        printf "   ${DIM}Instala con: $PKG_HINT${NC}\n" "$pkg"
        MISSING+=("$cmd")
    else
        ok "$cmd disponible"
    fi
}

check_cmd git git
check_cmd jq jq

# bash >= 4
if [[ -n "${BASH_VERSION:-}" ]]; then
    BASH_MAJOR="${BASH_VERSION%%.*}"
    if (( BASH_MAJOR < 4 )); then
        warn "bash $BASH_VERSION (se requiere >= 4)"
        MISSING+=("bash")
    else
        ok "bash $BASH_VERSION"
    fi
else
    warn "No se pudo detectar versión de bash"
fi

# node >= 20
if command -v node >/dev/null 2>&1; then
    NODE_MAJOR="$(node -v | sed 's/v//' | cut -d. -f1)"
    if (( NODE_MAJOR < 20 )); then
        warn "node $(node -v) (se requiere >= 20)"
        printf "   ${DIM}Instala con: $PKG_HINT${NC}\n" "nodejs"
        MISSING+=("node")
    else
        ok "node $(node -v)"
    fi
else
    warn "node no instalado (>= 20)"
    printf "   ${DIM}Instala con: $PKG_HINT${NC}\n" "nodejs"
    MISSING+=("node")
fi

if (( ${#MISSING[@]} > 0 )); then
    err "Faltan prerequisitos: ${MISSING[*]}"
    echo ""
    echo "  Instala lo necesario y vuelve a ejecutar."
    exit 1
fi

# ──────────────────────────────────────────────────────────
# PASO 3: Clonar o actualizar fuente
# ──────────────────────────────────────────────────────────
step "[3/6] Sincronizando fuente en $SRC_DIR"

if [[ ! -d "$SRC_DIR/.git" ]]; then
    if [[ -d "$SRC_DIR" ]]; then
        err "$SRC_DIR existe pero no es un repo git. Borra o mueve manualmente."
        exit 1
    fi
    echo "  Clonando $REPO_URL ..."
    git clone --depth 1 "$REPO_URL" "$SRC_DIR"
    ok "Repo clonado"
else
    echo "  Actualizando (git pull --ff-only) ..."
    if ! ( cd "$SRC_DIR" && git pull --ff-only 2>&1 ); then
        err "git pull --ff-only falló. ¿Tienes commits locales en $SRC_DIR?"
        echo "  ${DIM}Revisa manualmente: cd $SRC_DIR && git status${NC}"
        exit 1
    fi
    ok "Repo actualizado"
fi

# ──────────────────────────────────────────────────────────
# PASO 4: Backup pre-install (si hay instalación previa)
# ──────────────────────────────────────────────────────────
step "[4/6] Backup previo a la instalación"
BACKUP_SH="$SRC_DIR/scripts/backup.sh"

if [[ -d "$RUNTIME_DIR" ]] && [[ -f "$RUNTIME_DIR/settings.json" ]]; then
    if [[ -x "$BACKUP_SH" ]]; then
        echo "  Respaldando configuración actual (memoria del usuario)..."
        if bash "$BACKUP_SH" --label "pre-install-$(date +%F)" --quiet; then
            ok "Backup completado"
        else
            warn "Backup falló (no crítico), continuando"
        fi
    else
        chmod +x "$BACKUP_SH" 2>/dev/null || true
        if [[ -f "$BACKUP_SH" ]]; then
            bash "$BACKUP_SH" --label "pre-install-$(date +%F)" --quiet \
                && ok "Backup completado" \
                || warn "Backup falló (continuando)"
        else
            warn "backup.sh no disponible aún (repo desactualizado); continuando sin backup"
        fi
    fi
else
    echo "  ${DIM}(sin instalación previa en $RUNTIME_DIR)${NC}"
fi

# ──────────────────────────────────────────────────────────
# PASO 5: Ejecutar install-linux.sh
# ──────────────────────────────────────────────────────────
step "[5/6] Ejecutando instalador principal"
INSTALLER="$SRC_DIR/scripts/install-linux.sh"

if [[ ! -f "$INSTALLER" ]]; then
    err "No se encontró $INSTALLER"
    exit 1
fi

chmod +x "$INSTALLER" 2>/dev/null || true

# Pasar flags al instalador
if (( ${#PASSTHROUGH[@]} > 0 )); then
    bash "$INSTALLER" "${PASSTHROUGH[@]}"
else
    bash "$INSTALLER"
fi

# ──────────────────────────────────────────────────────────
# PASO 6: Resumen final
# ──────────────────────────────────────────────────────────
step "[6/6] Resumen"

VERSION="desconocida"
if [[ -f "$RUNTIME_DIR/.version" ]]; then
    VERSION="$(cat "$RUNTIME_DIR/.version" 2>/dev/null | tr -d '[:space:]')"
fi

echo ""
echo -e "  ${GREEN}${BOLD}Instalación completa${NC}"
echo -e "    versión:  ${BOLD}$VERSION${NC}"
echo -e "    fuente:   ${DIM}$SRC_DIR${NC}"
echo -e "    runtime:  ${DIM}$RUNTIME_DIR${NC}"
echo -e "    backups:  ${DIM}$RUNTIME_DIR/.backups/${NC}"
echo ""
echo -e "  ${CYAN}Siguientes pasos:${NC}"
echo -e "    ${BOLD}omnicoder --version${NC}                  # verificar CLI"
echo -e "    ${BOLD}bash $SRC_DIR/scripts/restore.sh list${NC}  # ver backups"
echo ""

trap - ERR
exit 0
