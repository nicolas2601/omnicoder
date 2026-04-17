#!/usr/bin/env bash
# ============================================================
# OmniCoder - Restaurar backups del runtime (~/.omnicoder/)
# v4.3 - list / restore / pin / unpin / prune
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ──────────────────────────────────────────────────────────
# Paleta compartida (_colors.sh auto-deshabilita si no TTY / NO_COLOR)
# ──────────────────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/_colors.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/_colors.sh"
else
    if [[ -t 1 ]]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
        BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; NC=''
    fi
fi

OMNI_HOME="${OMNICODER_HOME:-$HOME/.omnicoder}"
BACKUP_DIR="$OMNI_HOME/.backups"
MANIFEST="$BACKUP_DIR/manifest.json"
BACKUP_SH="$SCRIPT_DIR/backup.sh"

ASSUME_YES=false

err() { echo -e "${RED}ERROR:${NC} $*" >&2; }
info() { echo -e "$@"; }

trap 'rc=$?; exit $rc' ERR EXIT INT TERM

show_help() {
    cat <<EOF
${BOLD}OmniCoder restore.sh${NC} - Gestión de backups del runtime

${BOLD}Uso:${NC}
  restore.sh list                    Lista backups disponibles
  restore.sh restore <N|latest|path> Restaura un backup (hace backup previo)
  restore.sh pin <N>                 Marca un backup como pinned (no se purga)
  restore.sh unpin <N>               Desmarca un backup pinned
  restore.sh prune                   Fuerza auto-prune (dispara backup.sh)
  restore.sh --help                  Muestra esta ayuda

${BOLD}Flags:${NC}
  --yes, -y        Saltar confirmación interactiva en restore

${BOLD}Ejemplos:${NC}
  restore.sh list
  restore.sh restore latest
  restore.sh restore 2 --yes
  restore.sh restore /ruta/a/backup.tar.gz
  restore.sh pin 3
EOF
}

# ──────────────────────────────────────────────────────────
# Reconstruir manifest desde archivos si está corrupto/ausente
# ──────────────────────────────────────────────────────────
rebuild_manifest() {
    mkdir -p "$BACKUP_DIR"
    echo '{"entries":[]}' > "$MANIFEST"
    local md5cmd
    if command -v md5sum >/dev/null; then md5cmd="md5sum"; else md5cmd="md5 -q"; fi

    for f in "$BACKUP_DIR"/omnicoder-backup-*.tar.gz; do
        [[ -f "$f" ]] || continue
        local is_pin=false
        [[ "$f" == *.pinned.tar.gz ]] && is_pin=true
        local md5v
        if [[ "$md5cmd" == "md5sum" ]]; then
            md5v="$(md5sum "$f" | awk '{print $1}')"
        else
            md5v="$(md5 -q "$f")"
        fi
        local sz
        sz=$(stat -c '%s' "$f" 2>/dev/null || stat -f '%z' "$f")
        local ts
        ts="$(basename "$f" | sed -E 's/omnicoder-backup-([0-9]+-[0-9]+).*/\1/')"
        local entry
        entry="$(jq -n --arg ts "$ts" --arg path "$f" --arg md5 "$md5v" \
            --arg label "(recovered)" --argjson size "$sz" --argjson pinned "$is_pin" \
            '{timestamp:$ts, path:$path, size:$size, md5:$md5, pinned:$pinned, label:$label}')"
        jq --argjson e "$entry" '.entries += [$e]' "$MANIFEST" > "$MANIFEST.tmp" \
            && mv "$MANIFEST.tmp" "$MANIFEST"
    done
}

ensure_manifest() {
    mkdir -p "$BACKUP_DIR"
    if [[ ! -s "$MANIFEST" ]] || ! jq empty "$MANIFEST" 2>/dev/null; then
        info "${YELLOW}!!${NC} Manifest ausente/corrupto, reconstruyendo..."
        rebuild_manifest
    fi
}

# Devuelve lista ordenada (más recientes primero) como JSON array
get_sorted_entries() {
    jq '.entries | sort_by(.timestamp) | reverse' "$MANIFEST"
}

# Formato de tamaño humano
human_size() {
    local b=$1
    if (( b < 1024 )); then echo "${b}B"
    elif (( b < 1048576 )); then echo "$(( b / 1024 ))K"
    else awk -v b="$b" 'BEGIN{printf "%.1fM", b/1048576}'; fi
}

# ──────────────────────────────────────────────────────────
# Comandos
# ──────────────────────────────────────────────────────────
cmd_list() {
    ensure_manifest
    local count
    count=$(jq '.entries | length' "$MANIFEST")
    if (( count == 0 )); then
        info "${DIM}No hay backups en $BACKUP_DIR${NC}"
        return 0
    fi

    info "${BOLD}Backups disponibles:${NC} ($count total)"
    info ""
    printf "${BOLD}%-4s %-18s %-8s %-7s %s${NC}\n" "#" "TIMESTAMP" "SIZE" "PINNED" "LABEL"
    printf "%-4s %-18s %-8s %-7s %s\n" "---" "-----------------" "-------" "------" "-----"

    local idx=1
    while IFS=$'\t' read -r ts size pinned label; do
        local hs
        hs=$(human_size "$size")
        local pin_mark="no"
        [[ "$pinned" == "true" ]] && pin_mark="${CYAN}yes${NC}"
        [[ -z "$label" ]] && label="${DIM}(sin label)${NC}"
        printf "%-4s %-18s %-8s %-7b %b\n" "$idx" "$ts" "$hs" "$pin_mark" "$label"
        idx=$((idx + 1))
    done < <(get_sorted_entries | jq -r '.[] | [.timestamp, .size, .pinned, .label] | @tsv')

    info ""
    info "  ${DIM}Usa:${NC} ${BOLD}restore.sh restore <N>${NC} para restaurar"
}

# Resuelve selector (N|latest|path) a una ruta existente
resolve_backup() {
    local selector="$1"
    ensure_manifest

    if [[ -f "$selector" ]]; then
        echo "$selector"; return 0
    fi

    if [[ "$selector" == "latest" ]]; then
        local p
        p="$(get_sorted_entries | jq -r '.[0].path // empty')"
        [[ -n "$p" ]] && [[ -f "$p" ]] && { echo "$p"; return 0; }
        err "No hay backups disponibles"; return 1
    fi

    if [[ "$selector" =~ ^[0-9]+$ ]]; then
        local idx=$((selector - 1))
        local p
        p="$(get_sorted_entries | jq -r --argjson i "$idx" '.[$i].path // empty')"
        if [[ -n "$p" ]] && [[ -f "$p" ]]; then echo "$p"; return 0; fi
        err "Índice $selector fuera de rango"; return 1
    fi

    err "Selector inválido: $selector"
    return 1
}

cmd_restore() {
    local selector="${1:-}"
    if [[ -z "$selector" ]]; then
        err "Falta argumento: restore.sh restore <N|latest|path>"
        exit 2
    fi

    local target
    target="$(resolve_backup "$selector")" || exit 1

    info "${BLUE}[restore]${NC} Backup seleccionado:"
    info "  ${BOLD}$target${NC}"
    local sz
    sz=$(stat -c '%s' "$target" 2>/dev/null || stat -f '%z' "$target")
    info "  ${DIM}tamaño: $(human_size "$sz")${NC}"
    info ""

    if ! $ASSUME_YES; then
        if [[ ! -t 0 ]]; then
            err "Se requiere confirmación pero no hay TTY. Usa --yes para forzar."
            exit 1
        fi
        info "${YELLOW}${BOLD}ATENCIÓN:${NC} Esto sobreescribirá archivos en $OMNI_HOME"
        info "  (Se creará un backup automático del estado actual antes de restaurar)"
        info ""
        local reply=""
        read -rp "  ¿Continuar? [y/N]: " reply || true
        if [[ "${reply,,}" != "y" ]] && [[ "${reply,,}" != "yes" ]]; then
            info "${DIM}Cancelado.${NC}"
            exit 0
        fi
    fi

    # Pre-restore backup
    if [[ -x "$BACKUP_SH" ]] && [[ -d "$OMNI_HOME" ]]; then
        info "${BLUE}[pre-restore]${NC} Respaldando estado actual..."
        bash "$BACKUP_SH" --label "pre-restore-$(date +%Y%m%d-%H%M%S)" --quiet \
            || info "${YELLOW}!!${NC} Pre-restore backup falló (continuando)"
    fi

    mkdir -p "$OMNI_HOME"
    info "${BLUE}[restore]${NC} Extrayendo..."
    tar xzf "$target" -C "$OMNI_HOME"

    info "  ${GREEN}OK${NC} Restaurado desde $(basename "$target")"
    info ""
    info "  ${DIM}Ejecuta:${NC} ${BOLD}bash scripts/install-linux.sh --doctor${NC} ${DIM}para verificar${NC}"
}

# Cambia flag pinned del backup N
set_pin() {
    local selector="$1"
    local new_state="$2"   # true / false

    local target
    target="$(resolve_backup "$selector")" || exit 1

    local basename_old basename_new new_path
    basename_old="$(basename "$target")"

    if [[ "$new_state" == "true" ]]; then
        if [[ "$basename_old" == *.pinned.tar.gz ]]; then
            info "${DIM}Ya está pinned.${NC}"
            return 0
        fi
        basename_new="${basename_old%.tar.gz}.pinned.tar.gz"
    else
        if [[ "$basename_old" != *.pinned.tar.gz ]]; then
            info "${DIM}No está pinned.${NC}"
            return 0
        fi
        basename_new="${basename_old%.pinned.tar.gz}.tar.gz"
    fi

    new_path="$(dirname "$target")/$basename_new"
    mv "$target" "$new_path"

    # Actualizar manifest
    jq --arg old "$target" --arg new "$new_path" --argjson pin "$new_state" \
        '.entries |= map(if .path==$old then .path=$new | .pinned=$pin else . end)' \
        "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"

    if [[ "$new_state" == "true" ]]; then
        info "  ${CYAN}pinned${NC} -> $(basename "$new_path")"
    else
        info "  ${DIM}unpinned${NC} -> $(basename "$new_path")"
    fi
}

cmd_pin()   { set_pin "${1:-}" true; }
cmd_unpin() { set_pin "${1:-}" false; }

cmd_prune() {
    ensure_manifest
    info "${BLUE}[prune]${NC} Forzando auto-prune vía backup.sh..."
    if [[ -x "$BACKUP_SH" ]]; then
        # backup.sh hace prune al final; crear uno con label marcador y luego dedup lo descarta
        bash "$BACKUP_SH" --label "prune-trigger" --quiet || true
        info "  ${GREEN}OK${NC} prune ejecutado"
    else
        err "backup.sh no encontrado en $SCRIPT_DIR"
        exit 1
    fi
}

# ──────────────────────────────────────────────────────────
# Main: parse subcommand + flags
# ──────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    show_help; exit 0
fi

SUBCMD="$1"; shift || true

# Extrae --yes/-y de los args restantes
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) ASSUME_YES=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done
set -- "${POSITIONAL[@]:-}"

case "$SUBCMD" in
    list|ls)        cmd_list ;;
    restore|rollback) cmd_restore "${1:-}" ;;
    pin)            cmd_pin "${1:-}" ;;
    unpin)          cmd_unpin "${1:-}" ;;
    prune)          cmd_prune ;;
    --help|-h|help) show_help ;;
    *)
        err "Subcomando desconocido: $SUBCMD"
        show_help
        exit 2 ;;
esac
