#!/usr/bin/env bash
# ============================================================
# Claude Code - Skill Router v3.2 (UserPromptSubmit)
#
# NOVEDAD v3.2: Detección de tecnologías + auto-ejecución de
# `npx skills find <tech>` con cache. Devuelve las skills del
# ecosistema directamente en el contexto. El agente NO puede
# ignorar porque ya tiene los resultados visibles.
# ============================================================
set -euo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // .prompt // ""' 2>/dev/null || echo "")

[[ ${#PROMPT} -lt 10 ]] && { echo '{}'; exit 0; }

SKILLS_DIR="$HOME/.qwen/skills"
AGENTS_DIR="$HOME/.qwen/agents"
CACHE_DIR="$HOME/.qwen/.cache"
MEM_DIR="$HOME/.qwen/memory"
SKILL_INDEX="$CACHE_DIR/skills-index.tsv"
AGENT_INDEX="$CACHE_DIR/agents-index.tsv"
SUGG_LOG="$CACHE_DIR/last-suggestion.json"
NPX_CACHE="$CACHE_DIR/npx-cache"

mkdir -p "$CACHE_DIR" "$NPX_CACHE"

build_skill_index() {
    : > "$SKILL_INDEX"
    for d in "$SKILLS_DIR"/*/; do
        local f="$d/SKILL.md"
        [[ -f "$f" ]] || continue
        local name desc
        name=$(basename "$d")
        desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" 2>/dev/null | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
        [[ -z "$desc" ]] && desc="$name"
        printf "%s\t%s\n" "$name" "$desc" >> "$SKILL_INDEX"
    done
}

build_agent_index() {
    : > "$AGENT_INDEX"
    while IFS= read -r f; do
        local name desc
        name=$(basename "$f" .md)
        desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" 2>/dev/null | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
        [[ -z "$desc" ]] && desc="$name"
        printf "%s\t%s\n" "$name" "$desc" >> "$AGENT_INDEX"
    done < <(find "$AGENTS_DIR" -name "*.md" -type f 2>/dev/null)
}

needs_rebuild() {
    local src="$1" idx="$2"
    [[ ! -s "$idx" ]] && return 0
    [[ ! -d "$src" ]] && return 1
    local s
    s=$(find "$src" -name "*.md" -newer "$idx" 2>/dev/null | head -1)
    [[ -n "$s" ]]
}

[[ -d "$SKILLS_DIR" ]] && needs_rebuild "$SKILLS_DIR" "$SKILL_INDEX" && build_skill_index
[[ -d "$AGENTS_DIR" ]] && needs_rebuild "$AGENTS_DIR" "$AGENT_INDEX" && build_agent_index

# --------------------------------------------------------
# Detección de tecnologías/dominios conocidos
# --------------------------------------------------------
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

declare -A TECH_KEYWORDS=(
    [laravel]=laravel
    [symfony]=symfony
    [react]=react
    [nextjs]="next.js"
    ["next.js"]="next.js"
    [vue]=vue
    [nuxt]=nuxt
    [svelte]=svelte
    [angular]=angular
    [django]=django
    [flask]=flask
    [fastapi]=fastapi
    [rails]="rails"
    ["ruby on rails"]="rails"
    [spring]=spring
    [express]=express
    [nestjs]=nestjs
    [expo]=expo
    ["react native"]="react native"
    [flutter]=flutter
    [swift]=swift
    [swiftui]=swiftui
    [kotlin]=kotlin
    [solidity]=solidity
    [rust]=rust
    [golang]=golang
    ["go"]=golang
    [unity]=unity
    [unreal]=unreal
    [godot]=godot
    [wordpress]=wordpress
    [drupal]=drupal
    [medusa]=medusa
    [shopify]=shopify
    [stripe]=stripe
    [supabase]=supabase
    [firebase]=firebase
    [prisma]=prisma
    [tailwind]=tailwind
    [nativewind]=nativewind
    [remotion]=remotion
    [playwright]=playwright
    [cypress]=cypress
    [jest]=jest
    [pytest]=pytest
    [docker]=docker
    [kubernetes]=kubernetes
    [terraform]=terraform
    [vercel]=vercel
    [netlify]=netlify
    [aws]=aws
    [gcp]=gcp
)

DETECTED_TECH=""
for keyword in "${!TECH_KEYWORDS[@]}"; do
    if [[ "$PROMPT_LOWER" == *"$keyword"* ]]; then
        DETECTED_TECH="${TECH_KEYWORDS[$keyword]}"
        break
    fi
done

# --------------------------------------------------------
# Tokenize
# --------------------------------------------------------
PROMPT_CLEAN=$(echo "$PROMPT_LOWER" | tr -c '[:alnum:]' ' ')
STOPWORDS=" el la los las un una de del y o que como para por con sin en sobre es son este esto mi tu su se lo le me te the and or for with this that can could would should help need want make create get puedes por favor please thanks gracias hacer dime voy proyecto tener haria vas hago hacer pasos primero antes empezar "

read -r -a TOK_ARR <<< "$(echo "$PROMPT_CLEAN" | xargs)"
FILTERED=()
for tok in "${TOK_ARR[@]}"; do
    [[ ${#tok} -lt 3 ]] && continue
    [[ " $STOPWORDS " == *" $tok "* ]] && continue
    FILTERED+=("$tok")
done

[[ ${#FILTERED[@]} -eq 0 ]] && [[ -z "$DETECTED_TECH" ]] && { echo '{}'; exit 0; }

TOKENS_STR="${FILTERED[*]}"
BIGRAMS=""
for ((i=0; i<${#FILTERED[@]}-1; i++)); do
    BIGRAMS+="${FILTERED[i]}_${FILTERED[i+1]} "
done

score_index() {
    local idx="$1"
    [[ -s "$idx" ]] || return
    awk -v tokens="$TOKENS_STR" -v bigrams="$BIGRAMS" '
    BEGIN { n = split(tokens, toks, " "); m = split(bigrams, bgs, " ") }
    {
        name = $1; $1 = ""
        desc = tolower($0); lname = tolower(name)
        gsub(/[_-]/, " ", lname)
        score = 0
        for (i=1;i<=n;i++) {
            t = toks[i]; if (t == "") continue
            tmp = desc; c = 0
            while (sub(t, "", tmp) > 0 && c < 3) c++
            score += c
            if (index(lname, t) > 0) score += 3
        }
        for (j=1;j<=m;j++) {
            bg = bgs[j]; if (bg == "") continue
            gsub("_", " ", bg)
            if (index(desc, bg) > 0) score += 2
            if (index(lname, bg) > 0) score += 2
        }
        if (score > 0) printf "%d\t%s\n", score, name
    }' "$idx" | sort -rn -k1,1 | head -3
}

TOP_SKILLS=$(score_index "$SKILL_INDEX" 2>/dev/null || true)
TOP_AGENTS=$(score_index "$AGENT_INDEX" 2>/dev/null || true)

adjust() {
    local name="$1" base="$2" adj=0
    if [[ -f "$MEM_DIR/ignored-skills.md" ]]; then
        local c
        c=$(grep -c "^$name |" "$MEM_DIR/ignored-skills.md" 2>/dev/null || echo 0)
        [[ "$c" -ge 3 ]] && adj=$((adj + 2))
    fi
    echo $((base + adj))
}

rescore() {
    local raw="$1" out=""
    while IFS=$'\t' read -r sc name; do
        [[ -z "$name" ]] && continue
        local a; a=$(adjust "$name" "$sc")
        out+="$a	$name"$'\n'
    done <<< "$raw"
    echo "$out" | sort -rn -k1,1 | head -3
}

TOP_SKILLS=$(rescore "$TOP_SKILLS")
TOP_AGENTS=$(rescore "$TOP_AGENTS")

MAX_SKILL_SCORE=0; TOP_SKILL=""
if [[ -n "$TOP_SKILLS" ]]; then
    FIRST=$(echo "$TOP_SKILLS" | head -1)
    MAX_SKILL_SCORE=$(echo "$FIRST" | awk -F'\t' '{print $1}')
    TOP_SKILL=$(echo "$FIRST" | awk -F'\t' '{print $2}')
fi

MAX_AGENT_SCORE=0; TOP_AGENT=""
if [[ -n "$TOP_AGENTS" ]]; then
    FIRST=$(echo "$TOP_AGENTS" | head -1)
    MAX_AGENT_SCORE=$(echo "$FIRST" | awk -F'\t' '{print $1}')
    TOP_AGENT=$(echo "$FIRST" | awk -F'\t' '{print $2}')
fi

LEVEL="HINT"; PREFIX="[HINT]"
if [[ "$MAX_SKILL_SCORE" -ge 6 ]] || [[ "$MAX_AGENT_SCORE" -ge 6 ]]; then
    LEVEL="HARD"; PREFIX="[OBLIGATORIO]"
elif [[ "$MAX_SKILL_SCORE" -ge 3 ]] || [[ "$MAX_AGENT_SCORE" -ge 3 ]]; then
    LEVEL="SOFT"; PREFIX="[SUGERIDO]"
fi

# --------------------------------------------------------
# AUTO-EJECUTAR npx skills find si hay tech detectada y
# no hay match local fuerte. Cache 1 hora.
# --------------------------------------------------------
NPX_RESULTS=""
if [[ -n "$DETECTED_TECH" ]] && [[ "$MAX_SKILL_SCORE" -lt 6 ]]; then
    CACHE_KEY=$(echo "$DETECTED_TECH" | md5sum | cut -d' ' -f1)
    CACHE_FILE="$NPX_CACHE/$CACHE_KEY"
    CACHE_AGE_LIMIT=3600

    USE_CACHE=0
    if [[ -f "$CACHE_FILE" ]]; then
        CACHE_MTIME=$(stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        AGE=$((NOW_TS - CACHE_MTIME))
        [[ "$AGE" -lt "$CACHE_AGE_LIMIT" ]] && USE_CACHE=1
    fi

    if [[ "$USE_CACHE" == "1" ]]; then
        NPX_RESULTS=$(cat "$CACHE_FILE")
    elif command -v npx >/dev/null 2>&1; then
        # Timeout 10s para no bloquear el prompt
        NPX_RAW=$(timeout 10 npx --yes skills find "$DETECTED_TECH" 2>/dev/null | head -c 2500 || echo "")
        if [[ -n "$NPX_RAW" ]]; then
            # Strip ANSI color codes + tr cleanup
            NPX_RESULTS=$(echo "$NPX_RAW" | sed 's/\x1b\[[0-9;]*m//g' | head -n 20 | tr -d '\r')
            # Remove the ASCII banner (SKILLS logo)
            NPX_RESULTS=$(echo "$NPX_RESULTS" | grep -v '█\|╔\|╗\|╚\|╝\|║\|═' | grep -v '^$' | head -n 15)
            echo "$NPX_RESULTS" > "$CACHE_FILE"
        fi
    fi
fi

# Guardar sugerencia para tracker
if [[ -n "$TOP_SKILL" ]] || [[ -n "$TOP_AGENT" ]]; then
    jq -n --arg ts "$(date -Iseconds)" \
          --arg skill "$TOP_SKILL" --arg agent "$TOP_AGENT" \
          --argjson sscore "$MAX_SKILL_SCORE" --argjson ascore "$MAX_AGENT_SCORE" \
          --arg level "$LEVEL" \
          --arg prompt "$(echo "$PROMPT" | head -c 200)" \
          --arg tech "$DETECTED_TECH" \
          '{ts:$ts, skill:$skill, agent:$agent, skill_score:$sscore, agent_score:$ascore, level:$level, prompt:$prompt, tech:$tech}' \
          > "$SUGG_LOG"
fi

# --------------------------------------------------------
# Construir contexto — MUY IMPOSITIVO cuando hay tech + resultados
# --------------------------------------------------------
CTX=""

if [[ -n "$DETECTED_TECH" ]] && [[ -n "$NPX_RESULTS" ]]; then
    CTX="═══════════════════════════════════════════════════════════
🎯 TECNOLOGÍA DETECTADA: **$DETECTED_TECH**
═══════════════════════════════════════════════════════════

⚠️  PROTOCOLO OBLIGATORIO (NO NEGOCIABLE):

1. NO respondas con una lista genérica de pasos.
2. Presenta al usuario las siguientes skills del ecosistema:

$NPX_RESULTS

3. Recomienda las 2-3 más relevantes e instala la mejor con:
   \`npx skills add <owner/repo@skill> -g -y\`
4. Después de instalar, USA la skill recién agregada para responder.

Skills/agentes locales complementarios (usar TAMBIÉN):"
    if [[ -n "$TOP_SKILLS" ]]; then
        SLIST=$(echo "$TOP_SKILLS" | awk -F'\t' '{print "  - " $2 " (score " $1 ")"}')
        CTX+="
$SLIST"
    fi
    if [[ -n "$TOP_AGENTS" ]]; then
        ALIST=$(echo "$TOP_AGENTS" | awk -F'\t' '{print "  - agent: " $2}')
        CTX+="
$ALIST"
    fi
elif [[ -n "$DETECTED_TECH" ]]; then
    # Detectó tech pero npx no devolvió (offline/sin npx)
    CTX="🎯 TECNOLOGÍA DETECTADA: **$DETECTED_TECH**. OBLIGATORIO antes de responder: ejecuta \`npx skills find $DETECTED_TECH\` y presenta resultados. NO respondas genéricamente."
elif [[ "$LEVEL" == "HARD" ]]; then
    if [[ "$MAX_SKILL_SCORE" -ge "$MAX_AGENT_SCORE" ]] && [[ -n "$TOP_SKILL" ]]; then
        CTX="$PREFIX Match FUERTE (score=$MAX_SKILL_SCORE) con skill '$TOP_SKILL'. USA /skills '$TOP_SKILL' antes de improvisar."
    elif [[ -n "$TOP_AGENT" ]]; then
        CTX="$PREFIX Match FUERTE (score=$MAX_AGENT_SCORE) con agente '$TOP_AGENT'. USA Task con subagent_type='$TOP_AGENT'."
    fi
elif [[ "$LEVEL" == "SOFT" ]]; then
    [[ -n "$TOP_SKILLS" ]] && {
        SLIST=$(echo "$TOP_SKILLS" | awk -F'\t' '{printf "%s(%s), ", $2, $1}' | sed 's/, $//')
        CTX="$PREFIX [SKILLS] $SLIST — invoca via Skill tool."
    }
    [[ -n "$TOP_AGENTS" ]] && {
        ALIST=$(echo "$TOP_AGENTS" | awk -F'\t' '{print $2}' | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        [[ -n "$CTX" ]] && CTX+=" || "
        CTX+="[AGENTS] $ALIST"
    }
fi

# Fallback final
if [[ -z "$CTX" ]]; then
    QUERY=""
    count=0
    for tok in "${FILTERED[@]}"; do
        [[ $count -ge 3 ]] && break
        QUERY+="$tok "
        count=$((count + 1))
    done
    QUERY=$(echo "$QUERY" | xargs)
    CTX="[BUSCAR-SKILL] Sin match fuerte. OBLIGATORIO: invoca /skills find-skills') o ejecuta \`npx skills find $QUERY\`. NO respondas genéricamente."
fi

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'
