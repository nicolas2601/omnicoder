#!/usr/bin/env bash
# ============================================================
# OmniCoder - Provider Switcher (v3.5)
#
# Rota entre providers OpenAI-compatible guardando la config actual
# como backup. Uso:
#
#   ./switch-provider.sh nvidia    # MiniMax M2.7 via NVIDIA NIM (free)
#   ./switch-provider.sh gemini    # Gemini 2.5 Flash (free 1500/dia)
#   ./switch-provider.sh minimax   # MiniMax API directo (paid)
#   ./switch-provider.sh deepseek  # DeepSeek V3.2 (paid, cache 90% off)
#   ./switch-provider.sh openrouter  # OpenRouter con DeepSeek free
#   ./switch-provider.sh status    # Muestra provider actual
#   ./switch-provider.sh restore   # Restaura backup previo
#
# Las keys se leen de ~/.omnicoder/.env.<provider>.
# Template: ~/.omnicoder/.env.<provider>.example
# ============================================================
set -euo pipefail

OMNI_DIR="$HOME/.omnicoder"
ACTIVE_ENV="$OMNI_DIR/.env"
BACKUP_ENV="$OMNI_DIR/.env.backup"
SETTINGS="$OMNI_DIR/settings.json"

usage() {
    cat <<EOF
Uso: $0 <provider>
Providers disponibles:
  nvidia      MiniMax M2.7 via NVIDIA NIM  (FREE 40 rpm)
  gemini      Gemini 2.5 Flash             (FREE 1500/dia)
  minimax     MiniMax API directo          (paid Starter \$10)
  deepseek    DeepSeek V3.2                (paid, cache 90% off)
  openrouter  OpenRouter + DeepSeek free   (FREE)
  status      Muestra provider actual
  restore     Restaura backup previo
  list        Lista configs disponibles
EOF
    exit 1
}

[[ $# -lt 1 ]] && usage
ACTION="$1"

case "$ACTION" in
    status)
        if [[ -f "$ACTIVE_ENV" ]]; then
            grep -E "^OPENAI_(BASE_URL|MODEL)=" "$ACTIVE_ENV" | sed 's/OPENAI_//'
            echo "Model name in settings.json:"
            jq -r '.model.name' "$SETTINGS" 2>/dev/null
        else
            echo "⚠️ No hay .env activo"
        fi
        exit 0
        ;;
    restore)
        [[ -f "$BACKUP_ENV" ]] || { echo "⚠️ No hay backup en $BACKUP_ENV"; exit 1; }
        cp "$BACKUP_ENV" "$ACTIVE_ENV"
        chmod 600 "$ACTIVE_ENV"
        echo "✅ Backup restaurado desde $BACKUP_ENV"
        exit 0
        ;;
    list)
        echo "Configs guardadas en $OMNI_DIR:"
        ls -1 "$OMNI_DIR"/.env.* 2>/dev/null || echo "  (ninguna)"
        exit 0
        ;;
esac

# Backup .env actual antes de cambiar
if [[ -f "$ACTIVE_ENV" ]]; then
    cp "$ACTIVE_ENV" "$BACKUP_ENV"
    chmod 600 "$BACKUP_ENV"
fi

# Cargar config por provider
case "$ACTION" in
    nvidia)
        SRC="$OMNI_DIR/.env.nvidia"
        MODEL="minimaxai/minimax-m2.7"
        ;;
    gemini)
        SRC="$OMNI_DIR/.env.gemini"
        MODEL="gemini-2.5-flash"
        ;;
    minimax)
        SRC="$OMNI_DIR/.env.minimax"
        MODEL="MiniMax-M2"
        ;;
    deepseek)
        SRC="$OMNI_DIR/.env.deepseek"
        MODEL="deepseek-chat"
        ;;
    openrouter)
        SRC="$OMNI_DIR/.env.openrouter"
        MODEL="deepseek/deepseek-chat-v3-0324:free"
        ;;
    *)
        usage
        ;;
esac

if [[ ! -f "$SRC" ]]; then
    cat <<EOF
⚠️ Config no encontrada: $SRC

Crea el archivo con:
  OPENAI_API_KEY=<tu-key>
  OPENAI_BASE_URL=<base-url>
  OPENAI_MODEL=<modelo>

URLs sugeridas:
  nvidia     → https://integrate.api.nvidia.com/v1
  gemini     → https://generativelanguage.googleapis.com/v1beta/openai/
  minimax    → https://api.minimax.io/v1
  deepseek   → https://api.deepseek.com/v1
  openrouter → https://openrouter.ai/api/v1
EOF
    exit 1
fi

cp "$SRC" "$ACTIVE_ENV"
chmod 600 "$ACTIVE_ENV"

# Actualizar model.name en settings.json
if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg m "$MODEL" '.model.name = $m' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
fi

echo "✅ Provider cambiado a: $ACTION"
echo "   Model: $MODEL"
echo "   Env:   $ACTIVE_ENV (backup en $BACKUP_ENV)"
echo ""
echo "Reinicia OmniCoder: export \$(grep -v '^#' $ACTIVE_ENV | xargs) && omnicoder"
