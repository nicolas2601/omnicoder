#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Skill Router v3 (UserPromptSubmit)
# Hybrid scoring: BM25-like + bigramas + nombre + consultas
# a memoria (patterns, ignored-skills, learned) con enforcement
# adaptativo segun score.
#
# Niveles de enforcement:
#   score >= 6  -> [OBLIGATORIO] Usa skill X
#   score 3-5   -> [SUGERIDO] Considera skill X
#   score < 3   -> [HINT] /skills find-skills si es especializado
#
# Penalizaciones:
#   - Si skill aparece >=3 veces en ignored-skills.md -> +2 score (forzar)
#   - Si skill aparece en learned.md con error -> -2 score (penalizar)
#   - Si skill aparece en patterns.md (éxito previo) -> +1 score (boost)
# ============================================================
set -euo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""' 2>/dev/null || echo "")

[[ ${#PROMPT} -lt 8 ]] && { echo '{}'; exit 0; }

SKILLS_DIR="$HOME/.qwen/skills"
AGENTS_DIR="$HOME/.qwen/agents"
CACHE_DIR="$HOME/.qwen/.cache"
MEM_DIR="$HOME/.qwen/memory"
SKILL_INDEX="$CACHE_DIR/skills-index.tsv"
AGENT_INDEX="$CACHE_DIR/agents-index.tsv"
SUGGESTIONS_LOG="$CACHE_DIR/last-suggestions.json"

mkdir -p "$CACHE_DIR" "$MEM_DIR"

build_index() {
    local src="$1" idx="$2" pattern="$3"
    : > "$idx"
    if [[ "$pattern" == "skill" ]]; then
        for d in "$src"/*/; do
            local f="$d/SKILL.md"
            [[ -f "$f" ]] || continue
            local name desc
            name=$(basename "$d")
            desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" 2>/dev/null | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
            [[ -z "$desc" ]] && desc="$name"
            printf "%s\t%s\n" "$name" "$desc" >> "$idx"
        done
    else
        for f in "$src"/*.md; do
            [[ -f "$f" ]] || continue
            local name desc
            name=$(basename "$f" .md)
            desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" 2>/dev/null | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
            [[ -z "$desc" ]] && desc="$name"
            printf "%s\t%s\n" "$name" "$desc" >> "$idx"
        done
    fi
}

needs_rebuild() {
    local src="$1" idx="$2"
    [[ ! -s "$idx" ]] && return 0
    [[ ! -d "$src" ]] && return 1
    local src_mtime idx_mtime
    src_mtime=$(stat -c%Y "$src" 2>/dev/null || stat -f%m "$src" 2>/dev/null || echo 0)
    idx_mtime=$(stat -c%Y "$idx" 2>/dev/null || stat -f%m "$idx" 2>/dev/null || echo 0)
    [[ "$src_mtime" -gt "$idx_mtime" ]]
}

[[ -d "$SKILLS_DIR" ]] && needs_rebuild "$SKILLS_DIR" "$SKILL_INDEX" && build_index "$SKILLS_DIR" "$SKILL_INDEX" "skill"
[[ -d "$AGENTS_DIR" ]] && needs_rebuild "$AGENTS_DIR" "$AGENT_INDEX" "agent" && build_index "$AGENTS_DIR" "$AGENT_INDEX" "agent"

# --------------------------------------------------------
# Tokenize + bigramas
# --------------------------------------------------------
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' ' ')
STOPWORDS=" el la los las un una unos unas de del y o que quien como para por con sin en sobre es son fue era esta este esto mi tu su se lo le me te nos os the and or for with without about this that these those can could would should help need want make create get give quiero necesito puedes podrias hacer por favor please thanks gracias "

read -r -a TOKEN_ARR <<< "$(echo "$PROMPT_LOWER" | xargs)"
FILTERED=()
for tok in "${TOKEN_ARR[@]}"; do
    [[ ${#tok} -lt 3 ]] && continue
    [[ " $STOPWORDS " == *" $tok "* ]] && continue
    FILTERED+=("$tok")
done

[[ ${#FILTERED[@]} -eq 0 ]] && { echo '{}'; exit 0; }

TOKENS_STR="${FILTERED[*]}"

# Bigramas
BIGRAMS=""
for ((i=0; i<${#FILTERED[@]}-1; i++)); do
    BIGRAMS+="${FILTERED[i]}_${FILTERED[i+1]} "
done

# --------------------------------------------------------
# BM25-like scoring:
#  - tf en desc: +1 por ocurrencia (cap 3)
#  - token en nombre: +3 (nombre es señal fuerte)
#  - bigrama en desc o nombre: +2
# --------------------------------------------------------
score_index() {
    local idx="$1"
    [[ -s "$idx" ]] || return
    awk -v tokens="$TOKENS_STR" -v bigrams="$BIGRAMS" '
    BEGIN {
        n = split(tokens, toks, " ")
        m = split(bigrams, bgs, " ")
    }
    {
        name = $1
        $1 = ""
        desc = tolower($0)
        lname = tolower(name)
        gsub(/[_-]/, " ", lname)
        score = 0
        for (i = 1; i <= n; i++) {
            t = toks[i]
            if (t == "") continue
            # count occurrences in desc (cap 3)
            tmp = desc
            c = 0
            while (sub(t, "", tmp) > 0 && c < 3) c++
            score += c
            if (index(lname, t) > 0) score += 3
        }
        for (j = 1; j <= m; j++) {
            bg = bgs[j]
            if (bg == "") continue
            gsub("_", " ", bg)
            if (index(desc, bg) > 0) score += 2
            if (index(lname, bg) > 0) score += 2
        }
        if (score > 0) printf "%d\t%s\n", score, name
    }' "$idx" | sort -rn -k1,1 | head -5
}

TOP_SKILLS_RAW=$(score_index "$SKILL_INDEX" 2>/dev/null || true)
TOP_AGENTS_RAW=$(score_index "$AGENT_INDEX" 2>/dev/null || true)

# --------------------------------------------------------
# Aplicar memoria: ajustar scores segun patterns/ignored/learned
# --------------------------------------------------------
adjust_score() {
    local name="$1" base_score="$2"
    local adj=0

    # Boost si aparece en patterns.md (éxito previo)
    if [[ -f "$MEM_DIR/patterns.md" ]] && grep -qi "\b$name\b" "$MEM_DIR/patterns.md" 2>/dev/null; then
        adj=$((adj + 1))
    fi

    # Boost FUERTE si fue ignorado 3+ veces (forzar uso)
    if [[ -f "$MEM_DIR/ignored-skills.md" ]]; then
        local ign_count
        ign_count=$(grep -c "^$name |" "$MEM_DIR/ignored-skills.md" 2>/dev/null || echo 0)
        if [[ "$ign_count" -ge 3 ]]; then
            adj=$((adj + 2))
        fi
    fi

    # Penalizar si causó errores previos
    if [[ -f "$MEM_DIR/learned.md" ]] && grep -qi "skill.*$name.*error\|$name.*failed" "$MEM_DIR/learned.md" 2>/dev/null; then
        adj=$((adj - 2))
    fi

    echo $((base_score + adj))
}

# Re-scorear con ajustes de memoria
rescore() {
    local raw="$1"
    local out=""
    while IFS=$'\t' read -r sc name; do
        [[ -z "$name" ]] && continue
        local adjusted
        adjusted=$(adjust_score "$name" "$sc")
        out+="$adjusted	$name"$'\n'
    done <<< "$raw"
    echo "$out" | sort -rn -k1,1 | head -3
}

TOP_SKILLS=$(rescore "$TOP_SKILLS_RAW")
TOP_AGENTS=$(rescore "$TOP_AGENTS_RAW")

# --------------------------------------------------------
# Determinar nivel de enforcement (skill con score máximo)
# --------------------------------------------------------
MAX_SKILL_SCORE=0
TOP_SKILL_NAME=""
if [[ -n "$TOP_SKILLS" ]]; then
    FIRST_LINE=$(echo "$TOP_SKILLS" | head -1)
    MAX_SKILL_SCORE=$(echo "$FIRST_LINE" | awk -F'\t' '{print $1}')
    TOP_SKILL_NAME=$(echo "$FIRST_LINE" | awk -F'\t' '{print $2}')
fi

ENFORCE_LEVEL="HINT"
ENFORCE_PREFIX="[HINT]"
if [[ "$MAX_SKILL_SCORE" -ge 6 ]]; then
    ENFORCE_LEVEL="HARD"
    ENFORCE_PREFIX="[OBLIGATORIO]"
elif [[ "$MAX_SKILL_SCORE" -ge 3 ]]; then
    ENFORCE_LEVEL="SOFT"
    ENFORCE_PREFIX="[SUGERIDO]"
fi

# --------------------------------------------------------
# Consultar patterns / causal-edges / reflections
# --------------------------------------------------------
MEMORY_HINT=""
FIRST_TOKEN="${FILTERED[0]:-}"

if [[ -f "$MEM_DIR/patterns.md" ]] && [[ -n "$FIRST_TOKEN" ]]; then
    PAT=$(grep -i "^- " "$MEM_DIR/patterns.md" 2>/dev/null | grep -i "$FIRST_TOKEN" | head -1 || true)
    [[ -n "$PAT" ]] && MEMORY_HINT+="PATRON: $PAT || "
fi

if [[ -f "$MEM_DIR/causal-edges.md" ]] && [[ -n "$FIRST_TOKEN" ]]; then
    CAU=$(grep -i "$FIRST_TOKEN" "$MEM_DIR/causal-edges.md" 2>/dev/null | head -1 || true)
    [[ -n "$CAU" ]] && MEMORY_HINT+="CAUSAL: $CAU || "
fi

if [[ -f "$MEM_DIR/learned.md" ]] && [[ -n "$FIRST_TOKEN" ]]; then
    ERR=$(grep -i "$FIRST_TOKEN" "$MEM_DIR/learned.md" 2>/dev/null | head -1 || true)
    [[ -n "$ERR" ]] && MEMORY_HINT+="ERROR-PREVIO: $(echo "$ERR" | head -c 150) || "
fi

# --------------------------------------------------------
# Guardar sugerencias para usage-tracker (PostToolUse sabe qué se sugirió)
# --------------------------------------------------------
if [[ -n "$TOP_SKILL_NAME" ]]; then
    jq -n --arg prompt "$(echo "$PROMPT" | head -c 200)" \
          --arg skill "$TOP_SKILL_NAME" \
          --arg score "$MAX_SKILL_SCORE" \
          --arg level "$ENFORCE_LEVEL" \
          --arg ts "$(date -Iseconds)" \
          '{prompt:$prompt, top_skill:$skill, score:($score|tonumber), level:$level, ts:$ts}' \
          > "$SUGGESTIONS_LOG"
fi

# --------------------------------------------------------
# Construir contexto
# --------------------------------------------------------
CTX=""

if [[ "$ENFORCE_LEVEL" == "HARD" ]] && [[ -n "$TOP_SKILL_NAME" ]]; then
    CTX="$ENFORCE_PREFIX Esta tarea tiene match FUERTE (score=$MAX_SKILL_SCORE) con skill '$TOP_SKILL_NAME'. DEBES invocarla con /skills $TOP_SKILL_NAME antes de responder. No improvises cuando hay un skill especializado disponible."
    if [[ -n "$TOP_SKILLS" ]]; then
        OTHERS=$(echo "$TOP_SKILLS" | tail -n +2 | awk -F'\t' '{print $2}' | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        [[ -n "$OTHERS" ]] && CTX+=" Alternativas: $OTHERS."
    fi
elif [[ -n "$TOP_SKILLS" ]]; then
    SKILL_LIST=$(echo "$TOP_SKILLS" | awk -F'\t' '{printf "%s(score=%s), ", $2, $1}' | sed 's/, $//')
    CTX="$ENFORCE_PREFIX [SKILLS] $SKILL_LIST. Usa /skills <nombre> para invocar."
fi

if [[ -n "$TOP_AGENTS" ]]; then
    AGENT_LIST=$(echo "$TOP_AGENTS" | awk -F'\t' '{print $2}' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    [[ -n "$CTX" ]] && CTX+=" || "
    CTX+="[AGENTS] $AGENT_LIST"
fi

if [[ -n "$MEMORY_HINT" ]]; then
    [[ -n "$CTX" ]] && CTX+=" || "
    CTX+="[MEMORIA] ${MEMORY_HINT%|| }"
fi

# Si nivel HINT o sin contexto, forzar find-skills
if [[ "$ENFORCE_LEVEL" == "HINT" ]] || [[ -z "$CTX" ]]; then
    QUERY=""
    count=0
    for tok in "${FILTERED[@]}"; do
        [[ $count -ge 3 ]] && break
        QUERY+="$tok "
        count=$((count + 1))
    done
    QUERY=$(echo "$QUERY" | xargs)

    FIND_HINT="[BUSCAR-SKILL] Sin match fuerte local. OBLIGATORIO antes de improvisar: usa /skills find-skills o ejecuta: npx skills find $QUERY. Browse: https://skills.sh/"

    if [[ -z "$CTX" ]]; then
        CTX="$FIND_HINT"
    else
        CTX+=" || $FIND_HINT"
    fi
fi

jq -n --arg ctx "$CTX" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}'
