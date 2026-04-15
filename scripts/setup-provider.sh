#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Setup Provider Interactivo (v1.0)
#
# Pide la API key al usuario, genera ~/.qwen/.env.<provider>
# y activa el provider via switch-provider.sh
#
# Uso:
#   ./setup-provider.sh              # menu interactivo
#   ./setup-provider.sh nvidia       # va directo a nvidia
# ============================================================
set -euo pipefail

QWEN_DIR="$HOME/.qwen"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCHER="$SCRIPT_DIR/switch-provider.sh"

c_g='\033[0;32m'; c_y='\033[1;33m'; c_r='\033[0;31m'; c_b='\033[0;36m'; c_n='\033[0m'

mkdir -p "$QWEN_DIR"
chmod 700 "$QWEN_DIR" 2>/dev/null || true

declare -A URLS=(
    [nvidia]="https://integrate.api.nvidia.com/v1"
    [gemini]="https://generativelanguage.googleapis.com/v1beta/openai/"
    [minimax]="https://api.minimax.io/v1"
    [deepseek]="https://api.deepseek.com/v1"
    [openrouter]="https://openrouter.ai/api/v1"
)
declare -A MODELS=(
    [nvidia]="minimaxai/minimax-m2.7"
    [gemini]="gemini-2.5-flash"
    [minimax]="MiniMax-M2"
    [deepseek]="deepseek-chat"
    [openrouter]="deepseek/deepseek-chat-v3-0324:free"
)
declare -A SIGNUP=(
    [nvidia]="https://build.nvidia.com/  (gratis 40 RPM, ~1000 creditos)"
    [gemini]="https://aistudio.google.com/apikey  (gratis 1500/dia)"
    [minimax]="https://www.minimax.io/platform  (paid)"
    [deepseek]="https://platform.deepseek.com/  (paid, cache 90% off)"
    [openrouter]="https://openrouter.ai/keys  (free tier)"
)

choose_provider() {
    echo -e "${c_b}=== Qwen Con Poderes - Setup Provider ===${c_n}"
    echo ""
    echo "Providers disponibles:"
    echo "  1) nvidia      MiniMax M2.7 via NVIDIA NIM   [FREE 40 RPM] ${c_g}(recomendado)${c_n}"
    echo "  2) gemini      Gemini 2.5 Flash              [FREE 1500/dia]"
    echo "  3) minimax     MiniMax API directo           [paid Starter \$10]"
    echo "  4) deepseek    DeepSeek V3.2                 [paid, cache 90% off]"
    echo "  5) openrouter  OpenRouter + DeepSeek         [free tier]"
    echo ""
    read -rp "Eleccion [1-5, default=1]: " opt
    case "${opt:-1}" in
        1) PROVIDER=nvidia ;;
        2) PROVIDER=gemini ;;
        3) PROVIDER=minimax ;;
        4) PROVIDER=deepseek ;;
        5) PROVIDER=openrouter ;;
        *) echo -e "${c_r}Opcion invalida${c_n}"; exit 1 ;;
    esac
}

# Provider via arg o menu
if [[ $# -ge 1 ]]; then
    PROVIDER="$1"
    [[ -z "${URLS[$PROVIDER]:-}" ]] && { echo -e "${c_r}Provider desconocido: $PROVIDER${c_n}"; exit 1; }
else
    choose_provider
fi

BASE_URL="${URLS[$PROVIDER]}"
MODEL="${MODELS[$PROVIDER]}"
ENV_FILE="$QWEN_DIR/.env.$PROVIDER"

echo ""
echo -e "${c_b}Provider:${c_n} $PROVIDER"
echo -e "${c_b}Base URL:${c_n} $BASE_URL"
echo -e "${c_b}Modelo:${c_n}   $MODEL"
echo -e "${c_b}Registro:${c_n} ${SIGNUP[$PROVIDER]}"
echo ""

# Detectar si ya existe
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${c_y}Ya existe $ENV_FILE${c_n}"
    read -rp "Sobrescribir? [y/N]: " ow
    [[ "${ow,,}" != "y" ]] && { echo "Cancelado."; exit 0; }
fi

# Pedir API key (oculto)
echo ""
echo -n "Pega tu API key de $PROVIDER (no se mostrara): "
read -rs API_KEY
echo ""
[[ -z "$API_KEY" ]] && { echo -e "${c_r}API key vacia. Abortando.${c_n}"; exit 1; }
[[ ${#API_KEY} -lt 20 ]] && echo -e "${c_y}Aviso: la key parece corta (${#API_KEY} chars). Continuando...${c_n}"

# Escribir .env.<provider>
cat > "$ENV_FILE" <<EOF
# Generado por setup-provider.sh el $(date '+%Y-%m-%d %H:%M:%S')
OPENAI_API_KEY=$API_KEY
OPENAI_BASE_URL=$BASE_URL
OPENAI_MODEL=$MODEL
EOF
chmod 600 "$ENV_FILE"
echo -e "${c_g}OK escrito $ENV_FILE (permisos 600)${c_n}"

# Activar via switch-provider
if [[ -x "$SWITCHER" ]]; then
    echo ""
    echo "Activando provider..."
    "$SWITCHER" "$PROVIDER"
else
    echo -e "${c_y}switch-provider.sh no encontrado en $SWITCHER${c_n}"
    echo "Activa manualmente con: cp $ENV_FILE $QWEN_DIR/.env"
fi

# CRITICO: forzar selectedType=openai para que Qwen NO pida OAuth al arrancar
SETTINGS="$QWEN_DIR/settings.json"
if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq '.security = (.security // {}) | .security.auth = (.security.auth // {}) | .security.auth.selectedType = "openai"' \
        "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo -e "${c_g}OK auth.selectedType = openai (Qwen NO pedira OAuth)${c_n}"
elif [[ -f "$SETTINGS" ]]; then
    echo -e "${c_y}!! jq no instalado - edita $SETTINGS y agrega:${c_n}"
    echo '   "security": { "auth": { "selectedType": "openai" } }'
fi

# Eliminar OAuth cacheado si existe (sino prioriza sobre OpenAI key)
if [[ -f "$QWEN_DIR/oauth_creds.json" ]]; then
    echo ""
    read -rp "Encontre OAuth cacheado de Qwen. Eliminar para usar tu API key? [Y/n]: " rmoauth
    if [[ "${rmoauth,,}" != "n" ]]; then
        rm -f "$QWEN_DIR/oauth_creds.json"
        echo -e "${c_g}OK OAuth eliminado${c_n}"
    fi
fi

# Test opcional
echo ""
read -rp "Probar conexion con curl ahora? [Y/n]: " test
if [[ "${test,,}" != "n" ]]; then
    if command -v curl >/dev/null 2>&1; then
        echo "Enviando request de prueba..."
        HTTP=$(curl -s -o /tmp/qwen-test-$$.json -w "%{http_code}" \
            -X POST "${BASE_URL%/}/chat/completions" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":5}" \
            --max-time 15 || echo "000")
        if [[ "$HTTP" == "200" ]]; then
            echo -e "${c_g}OK conexion exitosa (HTTP 200)${c_n}"
        else
            echo -e "${c_r}Error HTTP $HTTP${c_n}"
            head -c 500 /tmp/qwen-test-$$.json 2>/dev/null; echo ""
        fi
        rm -f /tmp/qwen-test-$$.json
    else
        echo -e "${c_y}curl no disponible, skip test${c_n}"
    fi
fi

echo ""
echo -e "${c_g}Listo!${c_n} Arranca Qwen con:"
echo "  export \$(grep -v '^#' $QWEN_DIR/.env | xargs) && qwen"
