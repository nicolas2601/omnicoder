#!/usr/bin/env bash
# ============================================================
# OmniCoder - Skill Router v4.2 (UserPromptSubmit)
#
# NOVEDAD v3.3: Project Context Awareness. Escanea archivos del
# cwd (AGENTS.md, OMNICODER.md, QWEN.md, CLAUDE.md, README.md, package.json,
# go.mod, Cargo.toml, requirements.txt, composer.json, Gemfile,
# pubspec.yaml) para detectar tech aunque el prompt no la mencione.
# Cache por hash de cwd + mtime de archivos.
#
# v3.2: Detección de tecnologías + auto-ejecución de
# `npx skills find <tech>` con cache.
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // .prompt // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[[ -z "$CWD" ]] && CWD="$PWD"

[[ ${#PROMPT} -lt 10 ]] && { echo '{}'; exit 0; }

# v4.3: early-exit para prompts conversacionales cortos
# (saludos, confirmaciones, reacciones). Evita overhead + context bloat.
PROMPT_LC_TRIMMED=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | xargs)

# v4.3.2: slash commands nunca deben activar tech detection ni npx skills find.
case "$PROMPT_LC_TRIMMED" in
    /*) echo '{}'; exit 0 ;;
esac
if [[ ${#PROMPT_LC_TRIMMED} -lt 40 ]]; then
    case "$PROMPT_LC_TRIMMED" in
        hola|holi|holis|ok|okay|listo|gracias|genial|perfecto|sigue|continua|continuar|si|no|dale|vale|bien|mal|hola\ *|buenas*|buen\ dia*|buenos\ dias*|buenas\ tardes*|buenas\ noches*|que\ tal*|como\ estas*|como\ vas*|y\ ahora*|y\ bueno*)
            echo '{}'; exit 0 ;;
    esac
fi

SKILLS_DIR="$HOME/.omnicoder/skills"
AGENTS_DIR="$HOME/.omnicoder/agents"
CACHE_DIR="$HOME/.omnicoder/.cache"
MEM_DIR="$HOME/.omnicoder/memory"
SKILL_INDEX="$CACHE_DIR/skills-index.tsv"
AGENT_INDEX="$CACHE_DIR/agents-index.tsv"
SUGG_LOG="$CACHE_DIR/last-suggestion.json"
NPX_CACHE="$CACHE_DIR/npx-cache"
PROJ_CACHE="$CACHE_DIR/project-ctx"

mkdir -p "$CACHE_DIR" "$NPX_CACHE" "$PROJ_CACHE"

# v4.3.1: stopword stripping + truncate 80 chars. Coherente con build-skill-index.sh.
_STOPWORDS_RE='\b(the|for|with|this|that|and|or|a|an|of|in|on|to|from|by|as|is|are|be|use|used|when|how|what|which|you|your|via|into|at|it|its|not|has|have|all|any|can|will|should|would|could|may|one|two|three|other|using|also|etc|only|just|each|per|es|de|la|el|los|las|un|una|y|o|que|como|para|por|con|sin|en|sobre|este|esta|esto|estos|estas|son|ser|estar)\b'
_compress_desc() {
    tr '[:upper:]' '[:lower:]' \
      | sed -E "s/${_STOPWORDS_RE}//g" \
      | tr -s '[:space:]' ' ' \
      | sed 's/^ //;s/ $//' \
      | cut -c1-80
}

build_skill_index() {
    : > "$SKILL_INDEX"
    for d in "$SKILLS_DIR"/*/; do
        local f="$d/SKILL.md"
        [[ -f "$f" ]] || continue
        local name desc
        name=$(basename "$d")
        desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" 2>/dev/null | tr '\n' ' ')
        desc=$(echo "$desc" | _compress_desc)
        [[ -z "$desc" ]] && desc=$(echo "$name" | tr '-' ' ')
        printf "%s\t%s\n" "$name" "$desc" >> "$SKILL_INDEX"
    done
}

build_agent_index() {
    : > "$AGENT_INDEX"
    while IFS= read -r f; do
        local name desc
        name=$(basename "$f" .md)
        desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" 2>/dev/null | tr '\n' ' ')
        desc=$(echo "$desc" | _compress_desc)
        [[ -z "$desc" ]] && desc=$(echo "$name" | tr '-' ' ')
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

# v4.4: memoize needs_rebuild por 60s. Evita escanear 360+ archivos cada
# prompt. En sesiones largas reduce el router de ~200ms a ~15ms cuando
# tech cacheada. Si el usuario agrega un skill nuevo, espera hasta 60s
# (aceptable para un sistema interactivo).
REBUILD_CHECK="$CACHE_DIR/.rebuild-check"
_NOW_TS=$(date +%s)
_LAST_CHECK=$(cat "$REBUILD_CHECK" 2>/dev/null || echo 0)
_SKIP_REBUILD_CHECK=0
if [[ $((_NOW_TS - _LAST_CHECK)) -lt 60 ]] && [[ -s "$SKILL_INDEX" ]] && [[ -s "$AGENT_INDEX" ]]; then
    _SKIP_REBUILD_CHECK=1
fi

if [[ "$_SKIP_REBUILD_CHECK" != "1" ]]; then
    [[ -d "$SKILLS_DIR" ]] && needs_rebuild "$SKILLS_DIR" "$SKILL_INDEX" && build_skill_index
    [[ -d "$AGENTS_DIR" ]] && needs_rebuild "$AGENTS_DIR" "$AGENT_INDEX" && build_agent_index
    echo "$_NOW_TS" > "$REBUILD_CHECK" 2>/dev/null || true
fi

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

# --------------------------------------------------------
# v3.3: Escaneo del proyecto (cwd) — detecta tech en archivos
# --------------------------------------------------------
scan_project_context() {
    local cwd="$1"
    [[ ! -d "$cwd" ]] && return
    local key hash mtimes cache sig
    hash=$(echo -n "$cwd" | md5sum | cut -d' ' -f1)
    cache="$PROJ_CACHE/$hash"

    local files=(
        "$cwd/AGENTS.md" "$cwd/OMNICODER.md" "$cwd/QWEN.md" "$cwd/CLAUDE.md"
        "$cwd/README.md" "$cwd/README.MD" "$cwd/readme.md"
        "$cwd/package.json" "$cwd/go.mod" "$cwd/Cargo.toml"
        "$cwd/requirements.txt" "$cwd/pyproject.toml"
        "$cwd/composer.json" "$cwd/Gemfile" "$cwd/pubspec.yaml"
    )

    mtimes=""
    for f in "${files[@]}"; do
        [[ -f "$f" ]] && mtimes+="$(stat -c%Y "$f" 2>/dev/null || echo 0) "
    done
    sig=$(echo -n "$mtimes" | md5sum | cut -d' ' -f1)

    if [[ -f "$cache.sig" ]] && [[ "$(cat "$cache.sig" 2>/dev/null)" == "$sig" ]] && [[ -f "$cache" ]]; then
        cat "$cache"
        return
    fi

    local blob=""
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        blob+=" $(head -c 4096 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:].' ' ')"
    done

    echo "$blob" > "$cache"
    echo "$sig" > "$cache.sig"
    echo "$blob"
}

PROJECT_BLOB=$(scan_project_context "$CWD")

DETECTED_TECH=""
DETECTED_FROM=""
# v3.5: word-boundary match para evitar falsos positivos
# ("go" en "hago", "algoritmo", etc; "react" en "reaction")
for keyword in "${!TECH_KEYWORDS[@]}"; do
    escaped_kw="${keyword//./\\.}"
    if [[ " $PROMPT_LOWER " =~ [^a-z0-9]${escaped_kw}[^a-z0-9] ]]; then
        DETECTED_TECH="${TECH_KEYWORDS[$keyword]}"
        DETECTED_FROM="prompt"
        break
    fi
done

# Fallback: buscar en archivos del proyecto si el prompt no reveló tech
if [[ -z "$DETECTED_TECH" ]] && [[ -n "$PROJECT_BLOB" ]]; then
    for keyword in "${!TECH_KEYWORDS[@]}"; do
        if [[ "$PROJECT_BLOB" == *" $keyword "* ]] || [[ "$PROJECT_BLOB" == *" $keyword."* ]]; then
            DETECTED_TECH="${TECH_KEYWORDS[$keyword]}"
            DETECTED_FROM="project"
            break
        fi
    done
fi

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
            tmp = desc; c = 0; lt = length(t)
            while (lt > 0 && (p = index(tmp, t)) > 0 && c < 3) { c++; tmp = substr(tmp, p + lt) }
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
    # v3.5: blacklist de skills con falsos positivos frecuentes
    # Sus descripciones tienen keywords muy comunes que matchean de mas.
    # Requieren match explicito por nombre para activarse.
    case "$name" in
        seo-content|seo-audit|seo-page|seo-plan|seo-geo|seo-technical|seo-images|seo-sitemap|seo-schema|seo-programmatic|seo-competitor-pages|seo-hreflang|seo)
            if [[ "$PROMPT_LOWER" != *"seo"* ]] && [[ "$PROMPT_LOWER" != *"eeat"* ]] && [[ "$PROMPT_LOWER" != *"search engine"* ]]; then
                adj=$((adj - 10))
            fi ;;
        code-review|comprehensive-review|cross-review|review|plan-eng-review|plan-ceo-review|github-code-review)
            if [[ "$PROMPT_LOWER" != *"review"* ]] && [[ "$PROMPT_LOWER" != *"pr "* ]] && [[ "$PROMPT_LOWER" != *"revisa"* ]] && [[ "$PROMPT_LOWER" != *"audita"* ]] && [[ "$PROMPT_LOWER" != *"diff"* ]]; then
                adj=$((adj - 10))
            fi ;;
        docs-api-openapi|api-docs)
            if [[ "$PROMPT_LOWER" != *"openapi"* ]] && [[ "$PROMPT_LOWER" != *"swagger"* ]] && [[ "$PROMPT_LOWER" != *"documenta"* ]]; then
                adj=$((adj - 10))
            fi ;;
        roblox-avatar-creator|roblox-experience-designer|roblox-systems-scripter|specialized-developer-advocate)
            if [[ "$PROMPT_LOWER" != *"roblox"* ]] && [[ "$PROMPT_LOWER" != *"developer advocate"* ]] && [[ "$PROMPT_LOWER" != *"avatar"* ]]; then
                adj=$((adj - 15))
            fi ;;
        nano-banana-pro)
            if [[ "$PROMPT_LOWER" != *"imagen"* ]] && [[ "$PROMPT_LOWER" != *"image"* ]] && [[ "$PROMPT_LOWER" != *"banana"* ]] && [[ "$PROMPT_LOWER" != *"nano"* ]]; then
                adj=$((adj - 15))
            fi ;;
        find-skills)
            # find-skills solo si el usuario pide descubrir skills
            if [[ "$PROMPT_LOWER" != *"skill"* ]] && [[ "$PROMPT_LOWER" != *"descubre"* ]]; then
                adj=$((adj - 10))
            fi ;;
    esac
    if [[ -f "$MEM_DIR/ignored-skills.md" ]]; then
        local c
        # v4.3.1 fix: grep -c || echo 0 concatenaba "0\n0" con set -e,
        # rompiendo la aritmetica. Usar :- default + head -n1.
        c=$(grep -c "^$name |" "$MEM_DIR/ignored-skills.md" 2>/dev/null || true)
        c=$(echo "${c:-0}" | head -n1 | tr -cd '0-9')
        [[ "${c:-0}" -ge 3 ]] && adj=$((adj + 2))
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

# v3.5: thresholds subidos para reducir falsos positivos brutales
# Antes HARD=6/SOFT=3, eran demasiado permisivos (ej. seo-content score=48
# en prompts sobre NVIDIA API, roblox-avatar-creator en subagents paralelos).
LEVEL="HINT"; PREFIX="[HINT]"
if [[ "$MAX_SKILL_SCORE" -ge 12 ]] || [[ "$MAX_AGENT_SCORE" -ge 12 ]]; then
    LEVEL="HARD"; PREFIX="[OBLIGATORIO]"
elif [[ "$MAX_SKILL_SCORE" -ge 7 ]] || [[ "$MAX_AGENT_SCORE" -ge 7 ]]; then
    LEVEL="SOFT"; PREFIX="[SUGERIDO]"
fi

# --------------------------------------------------------
# AUTO-EJECUTAR npx skills find si hay tech detectada y
# no hay match local fuerte. Cache 1 hora.
# --------------------------------------------------------
NPX_RESULTS=""
# v4.3: cache 24h (era 1h), timeout 3s (era 10s), flag OMNICODER_SKIP_NPX
# para desactivar por completo en entornos lentos. Refresco en background.
if [[ -n "$DETECTED_TECH" ]] && [[ "$MAX_SKILL_SCORE" -lt 6 ]] && [[ "${OMNICODER_SKIP_NPX:-0}" != "1" ]]; then
    CACHE_KEY=$(echo "$DETECTED_TECH" | md5sum | cut -d' ' -f1)
    CACHE_FILE="$NPX_CACHE/$CACHE_KEY"
    CACHE_AGE_LIMIT=86400  # 24h

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
        # Cache stale: usar la version vieja si existe y refrescar en background.
        # Asi NUNCA bloqueamos la respuesta del LLM con un npx cold-start.
        if [[ -f "$CACHE_FILE" ]]; then
            NPX_RESULTS=$(cat "$CACHE_FILE")
        fi
        (
            NPX_RAW=$(timeout 15 npx --yes skills find "$DETECTED_TECH" 2>/dev/null | head -c 2500 || echo "")
            if [[ -n "$NPX_RAW" ]]; then
                FRESH=$(echo "$NPX_RAW" | sed 's/\x1b\[[0-9;]*m//g' | head -n 20 | tr -d '\r' | grep -v '█\|╔\|╗\|╚\|╝\|║\|═' | grep -v '^$' | head -n 15)
                echo "$FRESH" > "$CACHE_FILE"
            fi
        ) >/dev/null 2>&1 &
        disown 2>/dev/null || true
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
          --arg tech_source "$DETECTED_FROM" \
          '{ts:$ts, skill:$skill, agent:$agent, skill_score:$sscore, agent_score:$ascore, level:$level, prompt:$prompt, tech:$tech, tech_source:$tech_source}' \
          > "$SUGG_LOG"
fi

# --------------------------------------------------------
# Construir contexto — MUY IMPOSITIVO cuando hay tech + resultados
# --------------------------------------------------------
CTX=""

TECH_SOURCE_LABEL=""
[[ "$DETECTED_FROM" == "project" ]] && TECH_SOURCE_LABEL=" (desde archivos del proyecto: AGENTS.md/package.json/etc)"
[[ "$DETECTED_FROM" == "prompt" ]] && TECH_SOURCE_LABEL=" (mencionada en el prompt)"

if [[ -n "$DETECTED_TECH" ]] && [[ -n "$NPX_RESULTS" ]]; then
    # v4.3: output compacto. Antes: ~1500 chars inyectados en cada prompt
    # (rompia prompt cache del modelo). Ahora: resumen de 1 linea + top-3.
    NPX_COMPACT=$(echo "$NPX_RESULTS" | head -n 5 | tr '\n' ' | ' | head -c 400)
    CTX="[TECH:$DETECTED_TECH] Skills candidatas: $NPX_COMPACT"
    if [[ -n "$TOP_SKILLS" ]]; then
        SLIST=$(echo "$TOP_SKILLS" | awk -F'\t' '{printf "%s(%s), ", $2, $1}' | sed 's/, $//')
        CTX+=" | Locales: $SLIST"
    fi
elif [[ -n "$DETECTED_TECH" ]]; then
    CTX="[TECH:$DETECTED_TECH] Considera \`npx skills find $DETECTED_TECH\` si no hay match local."
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

# v4.3: fallback mucho mas silencioso. Antes forzaba [BUSCAR-SKILL] en
# casi todos los prompts sin match, inflando el contexto. Ahora solo emite
# si hay tokens relevantes Y el prompt es largo (sugiere tarea real).
if [[ -z "$CTX" ]] && [[ ${#FILTERED[@]} -ge 3 ]] && [[ ${#PROMPT} -gt 80 ]]; then
    QUERY=""
    count=0
    for tok in "${FILTERED[@]}"; do
        [[ $count -ge 3 ]] && break
        QUERY+="$tok "
        count=$((count + 1))
    done
    QUERY=$(echo "$QUERY" | xargs)
    CTX="[HINT] Sin skill con match fuerte. Si es dominio nuevo: \`npx skills find $QUERY\`."
fi

# Si sigue vacio, no inyectamos nada (evita context bloat en conversacional)
[[ -z "$CTX" ]] && { echo '{}'; exit 0; }

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'
