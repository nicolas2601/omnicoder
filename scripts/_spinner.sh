#!/usr/bin/env bash
# ============================================================
# OmniCoder v4.3 - Loading Spinner reutilizable
# ============================================================
# API:
#   spinner_start "mensaje"   # lanza spinner en background
#   spinner_stop              # detiene y limpia la linea
#   spinner_stop_ok "done"    # detiene y marca [OK]
#   spinner_stop_fail "msg"   # detiene y marca [!!]
#
# Auto-disable si stdout no es TTY, NO_COLOR o OMNI_NO_SPINNER.
# Siempre seguro: si el spinner no se inicio, los stop son no-op.
# ============================================================

# Cargar colores si no estan cargados (defensive)
if [[ -z "${__OMNI_COLORS_LOADED:-}" ]]; then
    __spinner_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || __spinner_dir="."
    if [[ -f "$__spinner_dir/_colors.sh" ]]; then
        # shellcheck disable=SC1091
        source "$__spinner_dir/_colors.sh"
    fi
fi

__OMNI_SPIN_PID=""
__OMNI_SPIN_MSG=""
__OMNI_SPIN_ENABLED=1

# Detectar si hay TTY / color
if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]] || [[ -n "${OMNI_NO_SPINNER:-}" ]]; then
    __OMNI_SPIN_ENABLED=0
fi

# Frames Braille (compatibles con UTF-8; fallback a ASCII si LANG no lo soporta)
__OMNI_SPIN_FRAMES_UNICODE=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
__OMNI_SPIN_FRAMES_ASCII=( '|' '/' '-' '\\' )

__omni_pick_frames() {
    if [[ "${LANG:-}${LC_ALL:-}" =~ [Uu][Tt][Ff] ]]; then
        printf '%s\n' "${__OMNI_SPIN_FRAMES_UNICODE[@]}"
    else
        printf '%s\n' "${__OMNI_SPIN_FRAMES_ASCII[@]}"
    fi
}

spinner_start() {
    __OMNI_SPIN_MSG="${1:-working}"
    if (( ! __OMNI_SPIN_ENABLED )); then
        printf '  %s ...\n' "$__OMNI_SPIN_MSG"
        return 0
    fi

    # Si ya hay uno corriendo, pararlo primero
    [[ -n "$__OMNI_SPIN_PID" ]] && spinner_stop

    # Ocultar cursor
    printf '\033[?25l'

    (
        local -a frames
        mapfile -t frames < <(__omni_pick_frames)
        local i=0
        local n=${#frames[@]}
        while :; do
            printf '\r  %b%s%b %s' "${OMNI_CYAN:-}" "${frames[$((i % n))]}" "${OMNI_NC:-}" "$__OMNI_SPIN_MSG"
            i=$((i + 1))
            sleep 0.08
        done
    ) &
    __OMNI_SPIN_PID=$!
    disown "$__OMNI_SPIN_PID" 2>/dev/null || true
}

__omni_spin_kill() {
    if [[ -n "$__OMNI_SPIN_PID" ]]; then
        kill "$__OMNI_SPIN_PID" 2>/dev/null || true
        wait "$__OMNI_SPIN_PID" 2>/dev/null || true
        __OMNI_SPIN_PID=""
    fi
    # Limpiar linea y mostrar cursor
    printf '\r\033[2K'
    printf '\033[?25h'
}

spinner_stop() {
    if (( ! __OMNI_SPIN_ENABLED )); then
        return 0
    fi
    __omni_spin_kill
}

spinner_stop_ok() {
    local msg="${1:-$__OMNI_SPIN_MSG}"
    if (( ! __OMNI_SPIN_ENABLED )); then
        printf '  [OK] %s\n' "$msg"
        return 0
    fi
    __omni_spin_kill
    printf '  %bOK%b %s\n' "${OMNI_GREEN:-}" "${OMNI_NC:-}" "$msg"
}

spinner_stop_fail() {
    local msg="${1:-$__OMNI_SPIN_MSG}"
    if (( ! __OMNI_SPIN_ENABLED )); then
        printf '  [!!] %s\n' "$msg"
        return 0
    fi
    __omni_spin_kill
    printf '  %b!!%b %s\n' "${OMNI_RED:-}" "${OMNI_NC:-}" "$msg"
}

# Asegurar que el cursor vuelve si el script se mata mientras hay spinner
trap '__omni_spin_kill 2>/dev/null || true' EXIT INT TERM
