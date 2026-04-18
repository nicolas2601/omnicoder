#!/usr/bin/env bash
# ============================================================
# OmniCoder - Sistema de backup del runtime (~/.omnicoder/)
# v4.3 - Comprimido + deduplicado + auto-prune + pinning
# ============================================================
set -euo pipefail

# ──────────────────────────────────────────────────────────
# Paleta compartida (_colors.sh auto-deshabilita si no TTY / NO_COLOR)
# ──────────────────────────────────────────────────────────
__BK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -f "$__BK_DIR/_colors.sh" ]]; then
    # shellcheck disable=SC1091
    source "$__BK_DIR/_colors.sh"
else
    # Fallback TTY-aware
    if [[ -t 1 ]]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
        BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
        DIM='\033[2m'; NC='\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; NC=''
    fi
fi

# ──────────────────────────────────────────────────────────
# Configuración
# ──────────────────────────────────────────────────────────
OMNI_HOME="${OMNICODER_HOME:-$HOME/.omnicoder}"
BACKUP_DIR="$OMNI_HOME/.backups"
MANIFEST="$BACKUP_DIR/manifest.json"
KEEP_BACKUPS=5

LABEL=""
PINNED=false
QUIET=false
TMP_TARBALL=""

# ──────────────────────────────────────────────────────────
# Trap limpieza
# ──────────────────────────────────────────────────────────
cleanup() {
    local rc=$?
    if [[ -n "$TMP_TARBALL" ]] && [[ -f "$TMP_TARBALL" ]]; then
        rm -f "$TMP_TARBALL" 2>/dev/null || true
    fi
    exit "$rc"
}
trap cleanup ERR EXIT INT TERM

# ──────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────
log() { $QUIET || echo -e "$@"; }
err() { echo -e "${RED}ERROR:${NC} $*" >&2; }

show_help() {
    cat <<EOF
${BOLD}OmniCoder backup.sh${NC} - Respalda la configuración del usuario en ~/.omnicoder/

${BOLD}Uso:${NC}
  backup.sh [--label "descripción"] [--pin] [--quiet] [--help]

${BOLD}Opciones:${NC}
  --label <texto>   Añade una etiqueta a la entry del manifest
  --pin             Crea el backup como .pinned.tar.gz (no se auto-purga)
  --quiet           Sin output excepto errores
  --help, -h        Muestra esta ayuda

${BOLD}Incluye:${NC}
  settings.json, .env, config/, memory/ (crítico), logs/ (último MB),
  .cache/ (solo índices)

${BOLD}Excluye:${NC}
  agents/, skills/, hooks/, commands/ (copias del repo), .git*

${BOLD}Comportamiento:${NC}
  - Deduplica por md5 (no crea backup idéntico si existe)
  - Auto-prune: mantiene los $KEEP_BACKUPS más recientes (pinned no cuentan)
  - Manifest en $MANIFEST

${BOLD}Destino:${NC}
  $BACKUP_DIR/omnicoder-backup-YYYYMMDD-HHMMSS.tar.gz
EOF
}

# ──────────────────────────────────────────────────────────
# Parse flags
# ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --label)
            [[ $# -ge 2 ]] || { err "--label requiere un valor"; exit 2; }
            LABEL="$2"; shift 2 ;;
        --label=*)
            LABEL="${1#--label=}"; shift ;;
        --pin)
            PINNED=true; shift ;;
        --quiet|-q)
            QUIET=true; shift ;;
        --help|-h)
            show_help; exit 0 ;;
        *)
            err "Flag desconocido: $1 (usa --help)"
            exit 2 ;;
    esac
done

# ──────────────────────────────────────────────────────────
# Validaciones previas
# ──────────────────────────────────────────────────────────
if [[ ! -d "$OMNI_HOME" ]]; then
    err "No existe $OMNI_HOME. Nada que respaldar."
    exit 1
fi

command -v tar >/dev/null || { err "tar no está instalado"; exit 1; }
command -v jq >/dev/null  || { err "jq no está instalado"; exit 1; }
command -v md5sum >/dev/null || command -v md5 >/dev/null || {
    err "Se requiere md5sum o md5"; exit 1; }

# md5 cross-platform
md5_of() {
    if command -v md5sum >/dev/null; then
        md5sum "$1" | awk '{print $1}'
    else
        md5 -q "$1"
    fi
}

mkdir -p "$BACKUP_DIR"

# ──────────────────────────────────────────────────────────
# Construir lista de inclusiones
# ──────────────────────────────────────────────────────────
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
if $PINNED; then
    FINAL_NAME="omnicoder-backup-${TIMESTAMP}.pinned.tar.gz"
else
    FINAL_NAME="omnicoder-backup-${TIMESTAMP}.tar.gz"
fi
FINAL_PATH="$BACKUP_DIR/$FINAL_NAME"
TMP_TARBALL="$(mktemp "${BACKUP_DIR}/.tmp-backup.XXXXXX.tar.gz")"

log "${BLUE}[backup]${NC} Creando snapshot de ${BOLD}$OMNI_HOME${NC}..."

# Contenido a incluir (rutas relativas a $OMNI_HOME)
INCLUDES=()
[[ -f "$OMNI_HOME/settings.json" ]]   && INCLUDES+=("settings.json")
[[ -f "$OMNI_HOME/.env" ]]            && INCLUDES+=(".env")
[[ -f "$OMNI_HOME/.version" ]]        && INCLUDES+=(".version")
[[ -f "$OMNI_HOME/OMNICODER.md" ]]    && INCLUDES+=("OMNICODER.md")
[[ -d "$OMNI_HOME/config" ]]          && INCLUDES+=("config")
[[ -d "$OMNI_HOME/memory" ]]          && INCLUDES+=("memory")

if [[ ${#INCLUDES[@]} -eq 0 ]]; then
    err "No se encontró contenido respaldable en $OMNI_HOME"
    exit 1
fi

# ──────────────────────────────────────────────────────────
# Staging de logs (último MB aprox) y .cache (solo índices)
# ──────────────────────────────────────────────────────────
STAGE_DIR="$(mktemp -d "${BACKUP_DIR}/.stage.XXXXXX")"
trap 'rm -rf "$STAGE_DIR" 2>/dev/null || true; cleanup' ERR EXIT INT TERM

if [[ -d "$OMNI_HOME/logs" ]]; then
    mkdir -p "$STAGE_DIR/logs"
    # Copia los N archivos más recientes hasta ~1MB
    BUDGET=$((1024 * 1024))   # 1 MB
    USED=0
    # Ordenar por mtime desc
    while IFS= read -r -d '' logfile; do
        size=$(stat -c '%s' "$logfile" 2>/dev/null || stat -f '%z' "$logfile" 2>/dev/null || echo 0)
        if (( USED + size > BUDGET )); then
            # Si es el primero y ya excede, incluir solo el último MB
            if (( USED == 0 )); then
                tail -c "$BUDGET" "$logfile" > "$STAGE_DIR/logs/$(basename "$logfile")" 2>/dev/null || true
                USED=$BUDGET
            fi
            break
        fi
        cp "$logfile" "$STAGE_DIR/logs/$(basename "$logfile")"
        USED=$(( USED + size ))
    done < <(find "$OMNI_HOME/logs" -maxdepth 1 -type f -printf '%T@ %p\0' 2>/dev/null \
             | sort -zrn | cut -z -d' ' -f2-)
fi

if [[ -d "$OMNI_HOME/.cache" ]]; then
    mkdir -p "$STAGE_DIR/.cache"
    # Solo índices (patrones conocidos); omitir caches transitorios
    find "$OMNI_HOME/.cache" -maxdepth 3 -type f \
        \( -name "*index*" -o -name "*.tsv" -o -name "*.idx" -o -name "manifest.json" \) \
        2>/dev/null | while IFS= read -r f; do
            rel="${f#$OMNI_HOME/.cache/}"
            mkdir -p "$STAGE_DIR/.cache/$(dirname "$rel")"
            cp "$f" "$STAGE_DIR/.cache/$rel" 2>/dev/null || true
        done
fi

# ──────────────────────────────────────────────────────────
# Crear tarball (excluyendo .git*)
# ──────────────────────────────────────────────────────────
TAR_ARGS=(
    --exclude='.git'
    --exclude='.gitignore'
    --exclude='.gitattributes'
    --exclude='*.swp'
    --exclude='*.tmp'
)

# Tarball sin gzip inicialmente (para append y luego gzip determinista)
TMP_RAW="$(mktemp "${BACKUP_DIR}/.raw.XXXXXX.tar")"

(
    cd "$OMNI_HOME"
    # --sort=name para orden determinista; --mtime fija timestamps; --owner/--group para repro
    tar cf "$TMP_RAW" \
        --sort=name \
        --mtime='@0' \
        --owner=0 --group=0 --numeric-owner \
        "${TAR_ARGS[@]}" "${INCLUDES[@]}" 2>/dev/null
)

# Adjuntar staging (si hay logs/cache trimmed)
if [[ -n "$(ls -A "$STAGE_DIR" 2>/dev/null)" ]]; then
    (cd "$STAGE_DIR" && tar rf "$TMP_RAW" \
        --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        . 2>/dev/null) || true
fi

# Gzip determinista (-n = no guarda nombre ni timestamp -> md5 estable)
gzip -n -c "$TMP_RAW" > "$TMP_TARBALL"
rm -f "$TMP_RAW"

rm -rf "$STAGE_DIR" 2>/dev/null || true

# Re-instalar trap sin STAGE_DIR
trap cleanup ERR EXIT INT TERM

# ──────────────────────────────────────────────────────────
# Calcular md5 y deduplicar
# ──────────────────────────────────────────────────────────
NEW_MD5="$(md5_of "$TMP_TARBALL")"
SIZE_BYTES=$(stat -c '%s' "$TMP_TARBALL" 2>/dev/null || stat -f '%z' "$TMP_TARBALL")

# Inicializa manifest si no existe o está corrupto
if [[ ! -s "$MANIFEST" ]] || ! jq empty "$MANIFEST" 2>/dev/null; then
    echo '{"entries":[]}' > "$MANIFEST"
fi

# Buscar duplicado por md5
DUPE_PATH="$(jq -r --arg m "$NEW_MD5" \
    '.entries[] | select(.md5==$m) | .path' "$MANIFEST" 2>/dev/null | head -n1)"

if [[ -n "$DUPE_PATH" ]] && [[ -f "$DUPE_PATH" ]]; then
    log "${YELLOW}INFO:${NC} backup idéntico a uno existente, skip"
    log "  ${DIM}$DUPE_PATH${NC}"
    rm -f "$TMP_TARBALL"
    TMP_TARBALL=""
    echo "$DUPE_PATH"
    # Prune igual (por si hubo unpin)
    :
else
    mv "$TMP_TARBALL" "$FINAL_PATH"
    TMP_TARBALL=""

    # Entry JSON
    ENTRY="$(jq -n \
        --arg ts "$TIMESTAMP" \
        --arg path "$FINAL_PATH" \
        --arg md5 "$NEW_MD5" \
        --arg label "$LABEL" \
        --argjson size "$SIZE_BYTES" \
        --argjson pinned "$PINNED" \
        '{timestamp:$ts, path:$path, size:$size, md5:$md5, pinned:$pinned, label:$label}')"

    jq --argjson e "$ENTRY" '.entries += [$e]' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"

    # Human size
    if (( SIZE_BYTES < 1024 )); then HUMAN="${SIZE_BYTES}B"
    elif (( SIZE_BYTES < 1048576 )); then HUMAN="$(( SIZE_BYTES / 1024 ))K"
    else HUMAN="$(awk -v b="$SIZE_BYTES" 'BEGIN{printf "%.1fM", b/1048576}')"; fi

    log "  ${GREEN}OK${NC} $(basename "$FINAL_PATH") (${HUMAN})"
    [[ -n "$LABEL" ]] && log "  ${DIM}label: $LABEL${NC}"
    $PINNED && log "  ${CYAN}pinned${NC} (no se auto-purga)"
fi

# ──────────────────────────────────────────────────────────
# Auto-prune: mantener KEEP_BACKUPS más recientes NO pinned
# ──────────────────────────────────────────────────────────
MAPFILE_OLD=()
while IFS= read -r line; do
    MAPFILE_OLD+=("$line")
done < <(
    jq -r '.entries
        | map(select(.pinned == false))
        | sort_by(.timestamp) | reverse
        | .['"$KEEP_BACKUPS"':][]?
        | .path' "$MANIFEST" 2>/dev/null
)

PRUNED=0
for old in "${MAPFILE_OLD[@]}"; do
    [[ -z "$old" ]] && continue
    rm -f "$old" 2>/dev/null || true
    jq --arg p "$old" '.entries |= map(select(.path != $p))' "$MANIFEST" > "$MANIFEST.tmp" \
        && mv "$MANIFEST.tmp" "$MANIFEST"
    PRUNED=$((PRUNED + 1))
done

if (( PRUNED > 0 )); then
    log "  ${DIM}auto-prune: $PRUNED backup(s) antiguo(s) eliminado(s)${NC}"
fi

# Limpieza de archivos huérfanos (no referenciados en manifest)
for f in "$BACKUP_DIR"/omnicoder-backup-*.tar.gz; do
    [[ -f "$f" ]] || continue
    if ! jq -e --arg p "$f" '.entries[] | select(.path==$p)' "$MANIFEST" >/dev/null 2>&1; then
        # Reconstituir entry si parece válido
        if [[ "$f" == *.pinned.tar.gz ]]; then
            IS_PIN=true
        else
            IS_PIN=false
        fi
        MD5V="$(md5_of "$f")"
        SZ=$(stat -c '%s' "$f" 2>/dev/null || stat -f '%z' "$f")
        TS="$(basename "$f" | sed -E 's/omnicoder-backup-([0-9]+-[0-9]+).*/\1/')"
        ENTRY="$(jq -n --arg ts "$TS" --arg path "$f" --arg md5 "$MD5V" \
            --arg label "" --argjson size "$SZ" --argjson pinned "$IS_PIN" \
            '{timestamp:$ts, path:$path, size:$size, md5:$md5, pinned:$pinned, label:$label}')"
        jq --argjson e "$ENTRY" '.entries += [$e]' "$MANIFEST" > "$MANIFEST.tmp" \
            && mv "$MANIFEST.tmp" "$MANIFEST"
    fi
done

# ──────────────────────────────────────────────────────────
# Output final: path del backup
# ──────────────────────────────────────────────────────────
if [[ -f "$FINAL_PATH" ]]; then
    log ""
    echo "$FINAL_PATH"
elif [[ -n "$DUPE_PATH" ]]; then
    :  # ya impreso arriba
fi

trap - ERR EXIT INT TERM
exit 0
