#!/usr/bin/env bash
# ============================================================
# OmniCoder - Skill Router LITE (v4.3.1, UserPromptSubmit)
#
# Decision tree:
#   1. Prompt <10 chars             -> {}
#   2. Conversacional               -> {}
#   3. <20 palabras sin tech kw     -> {}
#   4. Tech detectada + prompt corto -> [TECH:X]   (15-30 chars)
#   5. Prompt largo (>100 palabras) o tech nueva -> delega a skill-router.sh full
#
# Target: 80% prompts pasan por lite (0 bytes o 15 bytes inyectados).
# 20% delegan a full router (path completo BM25+bigramas+memoria).
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // .prompt // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[[ -z "$CWD" ]] && CWD="$PWD"

# 1) prompt demasiado corto -> nada
[[ ${#PROMPT} -lt 10 ]] && { echo '{}'; exit 0; }

PROMPT_LC=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
PROMPT_LC_TRIM=$(echo "$PROMPT_LC" | xargs)

# 2) conversacional / reacciones cortas
if [[ ${#PROMPT_LC_TRIM} -lt 40 ]]; then
    case "$PROMPT_LC_TRIM" in
        hola|holi|holis|ok|okay|listo|gracias|genial|perfecto|sigue|continua|continuar|si|no|dale|vale|bien|mal|hola\ *|buenas*|buen\ dia*|buenos\ dias*|buenas\ tardes*|buenas\ noches*|que\ tal*|como\ estas*|como\ vas*|y\ ahora*|y\ bueno*)
            echo '{}'; exit 0 ;;
    esac
fi

# Word count (aprox): contar tokens separados por espacio
WORD_COUNT=$(echo "$PROMPT_LC_TRIM" | awk '{print NF}')

# Keywords tech mas frecuentes (short list; full list en skill-router.sh)
TECH_KEYWORDS=(laravel symfony react vue nuxt svelte angular django flask fastapi rails spring express nestjs expo flutter swift swiftui kotlin solidity rust golang unity unreal godot wordpress drupal medusa shopify stripe supabase firebase prisma tailwind nativewind remotion playwright cypress jest pytest docker kubernetes terraform vercel netlify aws gcp nextjs)

DETECTED_TECH=""
for kw in "${TECH_KEYWORDS[@]}"; do
    if [[ " $PROMPT_LC " =~ [^a-z0-9]${kw}[^a-z0-9] ]]; then
        DETECTED_TECH="$kw"
        break
    fi
done

# 3) Prompt corto sin tech -> detectar si reciente hubo [TECH:X]
#    Cache en /tmp leida por skill-usage-tracker via `last-suggestion.json`.
RECENT_TECH=""
LAST_SUGG="$HOME/.omnicoder/.cache/last-suggestion.json"
if [[ -f "$LAST_SUGG" ]]; then
    # Solo usar si la sugerencia es reciente (<5 min)
    LAST_MTIME=$(stat -c%Y "$LAST_SUGG" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    if [[ $((NOW - LAST_MTIME)) -lt 300 ]]; then
        RECENT_TECH=$(jq -r '.tech // ""' "$LAST_SUGG" 2>/dev/null || echo "")
    fi
fi

# 4) Ruta rapida: tech detectada + prompt corto -> output minimo 15-30 chars
if [[ -n "$DETECTED_TECH" ]] && [[ "$WORD_COUNT" -le 20 ]]; then
    # Si ya hubo marker reciente con misma tech -> silencio
    if [[ "$RECENT_TECH" == "$DETECTED_TECH" ]]; then
        echo '{}'; exit 0
    fi
    jq -n --arg ctx "[TECH:$DETECTED_TECH]" \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'
    # Persistir para evitar re-emitir en proximo prompt
    mkdir -p "$HOME/.omnicoder/.cache"
    jq -n --arg tech "$DETECTED_TECH" --arg ts "$(date -Iseconds)" \
        '{ts:$ts, tech:$tech, skill:"", agent:"", level:"HINT"}' > "$LAST_SUGG" 2>/dev/null || true
    exit 0
fi

# 5) Prompt corto + sin tech -> silencio (default lite)
if [[ "$WORD_COUNT" -lt 20 ]] && [[ -z "$DETECTED_TECH" ]]; then
    echo '{}'; exit 0
fi

# 6) Prompt largo (>20 palabras) -> delegar al router full solo si la
#    complejidad lo amerita. Umbral: >100 palabras O mencion de tech + accion.
NEEDS_FULL=0
if [[ "$WORD_COUNT" -gt 100 ]]; then
    NEEDS_FULL=1
elif [[ -n "$DETECTED_TECH" ]] && [[ "$DETECTED_TECH" != "$RECENT_TECH" ]]; then
    NEEDS_FULL=1
elif [[ "$WORD_COUNT" -gt 40 ]]; then
    # Prompts de tamano medio con verbos de accion
    case "$PROMPT_LC" in
        *crea*|*implementa*|*refactor*|*revisa*|*audita*|*analiza*|*debug*|*optimiza*|*build*|*deploy*|*test*|*review*|*fix*|*write*|*generate*)
            NEEDS_FULL=1 ;;
    esac
fi

if [[ "$NEEDS_FULL" == "1" ]]; then
    # Delegar al router full pasando el mismo stdin
    FULL_ROUTER="$HOME/.omnicoder/hooks/skill-router.sh"
    [[ -x "$FULL_ROUTER" ]] || FULL_ROUTER="$(dirname "$0")/skill-router.sh"
    if [[ -f "$FULL_ROUTER" ]]; then
        echo "$INPUT" | bash "$FULL_ROUTER"
        exit $?
    fi
fi

# Fallback: sin match lite -> silencio
echo '{}'
