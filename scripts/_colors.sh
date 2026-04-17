#!/usr/bin/env bash
# ============================================================
# OmniCoder v4.3 - Paleta de colores ANSI compartida
# ============================================================
# Source desde cualquier script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/_colors.sh"
#
# Respeta las convenciones:
#   - NO_COLOR  (https://no-color.org/)   -> deshabilita colores
#   - OMNI_NO_COLOR=1                      -> deshabilita solo para OmniCoder
#   - stdout no-TTY                        -> deshabilita automaticamente
#
# Variables exportadas (prefijo OMNI_* para evitar colisiones):
#   OMNI_RED OMNI_GREEN OMNI_YELLOW OMNI_BLUE OMNI_CYAN OMNI_MAGENTA
#   OMNI_BOLD OMNI_DIM OMNI_UNDERLINE OMNI_NC
#
# Aliases sin prefijo (solo para compat con scripts viejos):
#   RED GREEN YELLOW BLUE CYAN MAGENTA BOLD DIM NC
# ============================================================

# Proteccion contra sourcing multiple (idempotente)
if [[ -n "${__OMNI_COLORS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

__omni_color_enabled=1

# Deshabilitar si NO_COLOR o OMNI_NO_COLOR estan seteados, o stdout no es TTY
if [[ -n "${NO_COLOR:-}" ]] || [[ -n "${OMNI_NO_COLOR:-}" ]]; then
    __omni_color_enabled=0
elif [[ ! -t 1 ]] && [[ -z "${OMNI_FORCE_COLOR:-}" ]]; then
    __omni_color_enabled=0
fi

if (( __omni_color_enabled )); then
    export OMNI_RED='\033[0;31m'
    export OMNI_GREEN='\033[0;32m'
    export OMNI_YELLOW='\033[1;33m'
    export OMNI_BLUE='\033[0;34m'
    export OMNI_CYAN='\033[0;36m'
    export OMNI_MAGENTA='\033[0;35m'
    export OMNI_BOLD='\033[1m'
    export OMNI_DIM='\033[2m'
    export OMNI_UNDERLINE='\033[4m'
    export OMNI_NC='\033[0m'
else
    export OMNI_RED='' OMNI_GREEN='' OMNI_YELLOW='' OMNI_BLUE=''
    export OMNI_CYAN='' OMNI_MAGENTA='' OMNI_BOLD='' OMNI_DIM=''
    export OMNI_UNDERLINE='' OMNI_NC=''
fi

# Aliases sin prefijo (compat). No exportamos: solo afectan al shell actual.
RED="$OMNI_RED"
GREEN="$OMNI_GREEN"
YELLOW="$OMNI_YELLOW"
BLUE="$OMNI_BLUE"
CYAN="$OMNI_CYAN"
MAGENTA="$OMNI_MAGENTA"
BOLD="$OMNI_BOLD"
DIM="$OMNI_DIM"
NC="$OMNI_NC"

# Helpers comunes
omni_ok()   { printf '%b%s%b %s\n' "$OMNI_GREEN"  'OK' "$OMNI_NC" "$*"; }
omni_warn() { printf '%b%s%b %s\n' "$OMNI_YELLOW" '!!' "$OMNI_NC" "$*"; }
omni_err()  { printf '%bERROR:%b %s\n' "$OMNI_RED" "$OMNI_NC" "$*" >&2; }
omni_info() { printf '%b%s%b %s\n' "$OMNI_BLUE"   '==>' "$OMNI_NC" "$*"; }
omni_step() { printf '%b%s%b %b%s%b\n' "$OMNI_BLUE" "$1" "$OMNI_NC" "$OMNI_BOLD" "${*:2}" "$OMNI_NC"; }
omni_dim()  { printf '%b%s%b\n' "$OMNI_DIM" "$*" "$OMNI_NC"; }

export __OMNI_COLORS_LOADED=1
