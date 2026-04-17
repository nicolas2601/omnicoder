#!/usr/bin/env bash
# ============================================================
# OmniCoder v4.3 - Desinstalador COMPLETO para Linux/macOS
#
# Elimina TODO: ~/.omnicoder/ (agentes, skills, hooks, commands,
# memoria, logs, caches, backups, .env, settings), ~/.qwen/
# (settings + OAuth caches), qwen CLI global, entradas de PATH
# y variable OMNICODER_HOME.
#
# Flags:
#   --keep-memory   Conserva ~/.omnicoder/memory/ (aprendizajes)
#   --keep-qwen     No desinstala qwen CLI (solo OmniCoder)
#   --force         No pide confirmacion
#   --dry-run       Solo muestra que eliminaria, no toca nada
#   --help          Esta ayuda
# ============================================================
set -euo pipefail

# Cargar paleta de colores unificada (v4.3)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/_colors.sh" ]]; then
    # shellcheck source=_colors.sh
    . "$SCRIPT_DIR/_colors.sh"
else
    OMNI_RED='\033[0;31m'; OMNI_GREEN='\033[0;32m'; OMNI_YELLOW='\033[1;33m'
    OMNI_CYAN='\033[0;36m'; OMNI_BOLD='\033[1m'; OMNI_DIM='\033[2m'; OMNI_NC='\033[0m'
fi

# Parseo de flags
KEEP_MEMORY=0
KEEP_QWEN=0
FORCE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --keep-memory) KEEP_MEMORY=1 ;;
        --keep-qwen)   KEEP_QWEN=1 ;;
        --force|-f|-y) FORCE=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --help|-h)
            sed -n '3,15p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *)
            echo -e "${OMNI_RED}Flag desconocido: $arg${OMNI_NC}"
            echo "Usa --help para ver las opciones."
            exit 1 ;;
    esac
done

# Detectar shell rc files (para limpiar PATH y OMNICODER_HOME)
_find_shell_rcs() {
    local rcs=()
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish"; do
        [[ -f "$rc" ]] && rcs+=("$rc")
    done
    printf '%s\n' "${rcs[@]}"
}

# Resumen de lo que se eliminara
echo ""
echo -e "${OMNI_CYAN}${OMNI_BOLD}=== OmniCoder - Desinstalador Completo ===${OMNI_NC}"
echo ""
echo -e "${OMNI_YELLOW}Esto eliminara:${OMNI_NC}"
echo "  - ~/.omnicoder/ (TODO el directorio, incluye:"
echo "    agents, skills, hooks, commands, config, logs, .cache, bin)"
[[ "$KEEP_MEMORY" == "0" ]] && echo "    + memory/ (aprendizajes, patterns, trajectories, causal-edges)"
[[ "$KEEP_MEMORY" == "1" ]] && echo -e "    ${OMNI_DIM}(memory/ se conserva: --keep-memory)${OMNI_NC}"
echo "  - ~/.qwen/settings.json, QWEN.md, commands/ y caches OAuth residuales"
[[ "$KEEP_QWEN" == "0" ]] && echo "  - Paquete global: @qwen-code/qwen-code (npm uninstall -g)"
[[ "$KEEP_QWEN" == "1" ]] && echo -e "  ${OMNI_DIM}(qwen CLI se conserva: --keep-qwen)${OMNI_NC}"
echo "  - Entradas de PATH a ~/.omnicoder en shell rcs"
echo "  - export OMNICODER_HOME en shell rcs"
echo ""

[[ "$DRY_RUN" == "1" ]] && { echo -e "${OMNI_DIM}--dry-run: no se tocara nada.${OMNI_NC}"; exit 0; }

if [[ "$FORCE" == "0" ]]; then
    read -rp "Continuar? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo "Cancelado."
        exit 0
    fi
fi

OMNI_HOME="$HOME/.omnicoder"
QWEN_HOME="$HOME/.qwen"
MEMORY_BACKUP=""

# 1. Backup de memoria si --keep-memory
if [[ "$KEEP_MEMORY" == "1" ]] && [[ -d "$OMNI_HOME/memory" ]]; then
    MEMORY_BACKUP="$HOME/.omnicoder-memory-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar czf "$MEMORY_BACKUP" -C "$OMNI_HOME" memory 2>/dev/null && \
        echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} memory/ respaldada en: $MEMORY_BACKUP"
fi

# 2. Eliminar ~/.omnicoder/
if [[ -d "$OMNI_HOME" ]]; then
    if [[ "$KEEP_MEMORY" == "1" ]] && [[ -d "$OMNI_HOME/memory" ]]; then
        # Eliminar todo excepto memory/
        find "$OMNI_HOME" -mindepth 1 -maxdepth 1 ! -name 'memory' -exec rm -rf {} + 2>/dev/null
        echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} ~/.omnicoder/ limpiado (memory/ conservada)"
    else
        rm -rf "$OMNI_HOME"
        echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} ~/.omnicoder/ eliminado completamente"
    fi
fi

# 3. Limpiar ~/.qwen/ (settings de qwen + OAuth caches + QWEN.md system prompt)
if [[ -d "$QWEN_HOME" ]]; then
    # v4.3.2: eliminar QWEN.md (lo creamos con install copiando OMNICODER.md)
    for f in settings.json QWEN.md oauth_creds.json access_token refresh_token .qwen_session auth.json; do
        [[ -f "$QWEN_HOME/$f" ]] && rm -f "$QWEN_HOME/$f"
    done
    # Borrar commands/ que instalamos (copias de ~/.omnicoder/commands/)
    [[ -d "$QWEN_HOME/commands" ]] && rm -rf "$QWEN_HOME/commands"
    # Si qwen home queda vacio, removerlo
    if [[ -z "$(ls -A "$QWEN_HOME" 2>/dev/null)" ]]; then
        rmdir "$QWEN_HOME" 2>/dev/null
        echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} ~/.qwen/ eliminado (estaba vacio tras limpieza)"
    else
        echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} ~/.qwen/ caches OAuth limpiados"
    fi
fi

# 4. Desinstalar qwen CLI global
if [[ "$KEEP_QWEN" == "0" ]]; then
    if command -v npm >/dev/null 2>&1; then
        if npm list -g --depth=0 2>/dev/null | grep -q '@qwen-code/qwen-code'; then
            npm uninstall -g @qwen-code/qwen-code >/dev/null 2>&1 && \
                echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} @qwen-code/qwen-code desinstalado"
        else
            echo -e "  ${OMNI_DIM}[--]${OMNI_NC} qwen CLI no estaba instalado globalmente"
        fi
    else
        echo -e "  ${OMNI_YELLOW}[!!]${OMNI_NC} npm no disponible, no se pudo desinstalar qwen CLI"
    fi
fi

# 5. Limpiar shell rcs: export OMNICODER_HOME + PATH entries
while IFS= read -r rc; do
    [[ -z "$rc" ]] && continue
    if grep -qE '(OMNICODER_HOME|\.omnicoder)' "$rc" 2>/dev/null; then
        cp "$rc" "$rc.omnicoder-backup-$(date +%Y%m%d)"
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i '/OMNICODER_HOME/d; /\.omnicoder\/bin/d; /# OmniCoder/d' "$rc"
        else
            sed -i '' '/OMNICODER_HOME/d;/\.omnicoder\/bin/d;/# OmniCoder/d' "$rc"
        fi
        echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} Limpiadas referencias en $(basename "$rc")"
    fi
done < <(_find_shell_rcs)

# 6. Symlinks globales (si install puso uno en /usr/local/bin)
for bin in /usr/local/bin/omnicoder "$HOME/.local/bin/omnicoder"; do
    [[ -L "$bin" ]] && rm -f "$bin" 2>/dev/null && echo -e "  ${OMNI_GREEN}[OK]${OMNI_NC} Symlink $bin removido"
done

echo ""
echo -e "${OMNI_CYAN}${OMNI_BOLD}Desinstalacion completa.${OMNI_NC}"
[[ -n "$MEMORY_BACKUP" ]] && echo -e "${OMNI_DIM}Tu memoria esta respaldada en: $MEMORY_BACKUP${OMNI_NC}"
echo ""
echo "Para reinstalar limpio:"
echo "  git clone https://github.com/nicolas2601/omnicoder.git"
echo "  cd omnicoder && ./scripts/install-linux.sh"
echo ""
echo -e "${OMNI_YELLOW}Reinicia tu terminal${OMNI_NC} para que los cambios en PATH surtan efecto."
