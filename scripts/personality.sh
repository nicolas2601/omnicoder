#!/usr/bin/env bash
# ============================================================
# OmniCoder - Personality CLI (v4.3.2)
#
# Gestiona la personalidad activa del agente. Cuando hay una
# personalidad activa, el hook personality-injector.sh la inyecta
# en cada UserPromptSubmit para que el LLM responda con ese tono.
#
# Uso:
#   personality.sh set <nombre>    Activa personalidad
#   personality.sh get             Muestra la activa
#   personality.sh list            Lista disponibles
#   personality.sh off             Desactiva (vuelve a normal)
#   personality.sh random          Elige una al azar
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/_colors.sh" ]]; then
    # shellcheck source=_colors.sh
    . "$SCRIPT_DIR/_colors.sh"
else
    OMNI_RED='\033[0;31m'; OMNI_GREEN='\033[0;32m'; OMNI_YELLOW='\033[1;33m'
    OMNI_CYAN='\033[0;36m'; OMNI_MAGENTA='\033[0;35m'; OMNI_BOLD='\033[1m'
    OMNI_DIM='\033[2m'; OMNI_NC='\033[0m'
fi

OMNI_DIR="${OMNICODER_HOME:-$HOME/.omnicoder}"
PERSONALITY_FILE="$OMNI_DIR/.personality"
PERSONALITIES_DIR="$OMNI_DIR/personalities"

# Lista canonica de personalidades soportadas
AVAILABLE=("omni-man" "conquest" "thragg" "anissa" "cecil" "immortal")

list_personalities() {
    echo ""
    echo -e "${OMNI_CYAN}${OMNI_BOLD}=== Personalidades disponibles ===${OMNI_NC}"
    echo ""
    echo -e "  ${OMNI_RED}${OMNI_BOLD}omni-man${OMNI_NC}  ${OMNI_DIM}Nolan Grayson - arrogante paternal. 'Piensa Mark, ¡PIENSA!'${OMNI_NC}"
    echo -e "  ${OMNI_MAGENTA}${OMNI_BOLD}conquest${OMNI_NC}  ${OMNI_DIM}Psicopata violento. Risas maniaticas, disfruta el caos.${OMNI_NC}"
    echo -e "  ${OMNI_YELLOW}${OMNI_BOLD}thragg${OMNI_NC}    ${OMNI_DIM}Emperador viltrumita. Frio, imperial, 'el imperio requiere...'${OMNI_NC}"
    echo -e "  ${OMNI_CYAN}${OMNI_BOLD}anissa${OMNI_NC}    ${OMNI_DIM}Arrogante sarcastica. 'Tu mente humana es limitada, pero util.'${OMNI_NC}"
    echo -e "  ${OMNI_GREEN}${OMNI_BOLD}cecil${OMNI_NC}     ${OMNI_DIM}Director GDA humano. Paranoico, pragmatico, anti-viltrumita.${OMNI_NC}"
    echo -e "  ${OMNI_BOLD}immortal${OMNI_NC}  ${OMNI_DIM}Heroe inmortal. Solemne, epico, referencias historicas.${OMNI_NC}"
    echo ""
    echo -e "${OMNI_DIM}Uso: /personality set <nombre> | off | random${OMNI_NC}"
}

get_current() {
    if [[ -f "$PERSONALITY_FILE" ]]; then
        local p
        p=$(cat "$PERSONALITY_FILE" 2>/dev/null | tr -d '[:space:]')
        [[ -n "$p" ]] && echo "$p" || echo "default"
    else
        echo "default"
    fi
}

set_personality() {
    local name="$1"
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | xargs)

    # Aliases
    case "$name" in
        omniman|nolan|grayson) name="omni-man" ;;
        anissa|viltrumita-f) name="anissa" ;;
        thragg|emperador|emperor) name="thragg" ;;
    esac

    # Validar
    local valid=0
    for p in "${AVAILABLE[@]}"; do
        [[ "$p" == "$name" ]] && valid=1
    done
    if [[ "$valid" == "0" ]]; then
        echo -e "${OMNI_RED}[!!] '${name}' no es una personalidad valida.${OMNI_NC}"
        echo ""
        list_personalities
        exit 1
    fi

    mkdir -p "$OMNI_DIR"
    echo "$name" > "$PERSONALITY_FILE"

    echo ""
    case "$name" in
        omni-man)
            echo -e "${OMNI_RED}${OMNI_BOLD}[OMNI-MAN ACTIVADO]${OMNI_NC}"
            echo -e "${OMNI_DIM}'Piensa, Mark... ¡PIENSA! ¿Que tendras en 500 anos? Nada.'${OMNI_NC}"
            ;;
        conquest)
            echo -e "${OMNI_MAGENTA}${OMNI_BOLD}[CONQUEST ACTIVADO]${OMNI_NC}"
            echo -e "${OMNI_DIM}'HAAAH! Finalmente algo interesante... code que sangre!'${OMNI_NC}"
            ;;
        thragg)
            echo -e "${OMNI_YELLOW}${OMNI_BOLD}[THRAGG ACTIVADO]${OMNI_NC}"
            echo -e "${OMNI_DIM}'El Imperio Viltrumita requiere excelencia. No decepciones.'${OMNI_NC}"
            ;;
        anissa)
            echo -e "${OMNI_CYAN}${OMNI_BOLD}[ANISSA ACTIVADA]${OMNI_NC}"
            echo -e "${OMNI_DIM}'Tu mente humana es limitada, pero voy a tolerar esta mision.'${OMNI_NC}"
            ;;
        cecil)
            echo -e "${OMNI_GREEN}${OMNI_BOLD}[CECIL STEDMAN ACTIVADO]${OMNI_NC}"
            echo -e "${OMNI_DIM}'Miralo, otro viltrumita tocando los c*juntos. OK hagamoslo.'${OMNI_NC}"
            ;;
        immortal)
            echo -e "${OMNI_BOLD}[IMMORTAL ACTIVADO]${OMNI_NC}"
            echo -e "${OMNI_DIM}'He visto imperios caer. Este bug no sera distinto.'${OMNI_NC}"
            ;;
    esac
    echo ""
    echo -e "${OMNI_DIM}La personalidad se inyecta en el proximo prompt. Desactiva con: /personality off${OMNI_NC}"
}

unset_personality() {
    if [[ -f "$PERSONALITY_FILE" ]]; then
        rm -f "$PERSONALITY_FILE"
        echo -e "${OMNI_GREEN}[OK]${OMNI_NC} Personalidad desactivada. Vuelves al OmniCoder estandar."
    else
        echo -e "${OMNI_DIM}Ya estabas en modo estandar.${OMNI_NC}"
    fi
}

random_personality() {
    local idx=$((RANDOM % ${#AVAILABLE[@]}))
    set_personality "${AVAILABLE[$idx]}"
}

case "${1:-}" in
    set)
        [[ -z "${2:-}" ]] && { echo "Uso: $0 set <nombre>"; exit 1; }
        set_personality "$2"
        ;;
    get|current|status)
        current=$(get_current)
        if [[ "$current" == "default" ]]; then
            echo -e "${OMNI_DIM}Personalidad: estandar (sin alter-ego activo)${OMNI_NC}"
        else
            echo -e "${OMNI_BOLD}Personalidad activa: ${OMNI_CYAN}$current${OMNI_NC}"
        fi
        ;;
    list|ls)
        list_personalities
        ;;
    off|reset|default|unset|disable)
        unset_personality
        ;;
    random|rand)
        random_personality
        ;;
    help|--help|-h|"")
        cat <<EOF

Uso: personality.sh <comando> [args]

  set <nombre>    Activar personalidad (omni-man, conquest, thragg, anissa, cecil, immortal)
  get             Mostrar personalidad activa
  list            Listar todas las personalidades con descripcion
  off             Desactivar (volver al OmniCoder estandar)
  random          Activar una al azar

Ejemplos:
  personality.sh set omni-man
  personality.sh set conquest
  personality.sh random
  personality.sh off
EOF
        ;;
    *)
        echo -e "${OMNI_RED}[!!] Comando desconocido: $1${OMNI_NC}"
        echo "Usa --help para ayuda."
        exit 1
        ;;
esac
