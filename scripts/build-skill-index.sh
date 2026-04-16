#!/usr/bin/env bash
# ============================================================
# OmniCoder - Build Skill Index
# Construye cache de skills y agentes para skill-router.sh v2.
# Uso: ./scripts/build-skill-index.sh
# ============================================================
set -euo pipefail

SKILLS_DIR="$HOME/.omnicoder/skills"
AGENTS_DIR="$HOME/.omnicoder/agents"
CACHE_DIR="$HOME/.omnicoder/.cache"
SKILL_INDEX="$CACHE_DIR/skills-index.tsv"
AGENT_INDEX="$CACHE_DIR/agents-index.tsv"

mkdir -p "$CACHE_DIR"

build_skills() {
    : > "$SKILL_INDEX"
    local n=0
    for d in "$SKILLS_DIR"/*/; do
        local f="$d/SKILL.md"
        [[ -f "$f" ]] || continue
        local name desc
        name=$(basename "$d")
        desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
        [[ -z "$desc" ]] && desc="$name"
        printf "%s\t%s\n" "$name" "$desc" >> "$SKILL_INDEX"
        n=$((n+1))
    done
    echo "  Skills indexadas: $n -> $SKILL_INDEX"
}

build_agents() {
    : > "$AGENT_INDEX"
    local n=0
    for f in "$AGENTS_DIR"/*.md; do
        [[ -f "$f" ]] || continue
        local name desc
        name=$(basename "$f" .md)
        desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$f" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
        [[ -z "$desc" ]] && desc="$name"
        printf "%s\t%s\n" "$name" "$desc" >> "$AGENT_INDEX"
        n=$((n+1))
    done
    echo "  Agentes indexados: $n -> $AGENT_INDEX"
}

echo "Construyendo indices..."
[[ -d "$SKILLS_DIR" ]] && build_skills || echo "  (skip) $SKILLS_DIR no existe"
[[ -d "$AGENTS_DIR" ]] && build_agents || echo "  (skip) $AGENTS_DIR no existe"
echo "Listo."
