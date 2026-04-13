#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Reflection Hook (Stop)
# Al terminar la sesión, genera una auto-reflexión (Reflexion
# pattern, Shinn et al. 2023) sobre:
#  - Skills sugeridos vs usados
#  - Errores recientes
#  - Éxitos (trayectorias)
#  - Destila lecciones a patterns.md (semantic memory)
# ============================================================
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

MEM_DIR="$HOME/.qwen/memory"
CACHE_DIR="$HOME/.qwen/.cache"
mkdir -p "$MEM_DIR"

REFLECTIONS_FILE="$MEM_DIR/reflections.md"
PATTERNS_FILE="$MEM_DIR/patterns.md"

if [[ ! -f "$REFLECTIONS_FILE" ]]; then
    cat > "$REFLECTIONS_FILE" <<'EOF'
# Auto-Reflexiones de Sesión

Resumen automático al final de cada sesión: qué funcionó, qué no,
qué skills se ignoraron. Destilado periódico a `patterns.md`.

---
EOF
fi

if [[ ! -f "$PATTERNS_FILE" ]]; then
    cat > "$PATTERNS_FILE" <<'EOF'
# Patrones Semánticos Destilados

Reglas reusables extraídas de trayectorias exitosas y reflexiones.
Este archivo tiene prioridad alta en el contexto inicial.

## Reglas Generales

---
EOF
fi

TIMESTAMP=$(date -Iseconds)
TODAY=$(date +%Y-%m-%d)

# Contar actividad reciente (última sesión)
ERRORS_TODAY=0
SUCCESS_TODAY=0
IGNORED_TODAY=0

if [[ -f "$MEM_DIR/learned.md" ]]; then
    ERRORS_TODAY=$(grep -c "^### $TODAY" "$MEM_DIR/learned.md" 2>/dev/null || echo 0)
fi
if [[ -f "$MEM_DIR/trajectories.md" ]]; then
    SUCCESS_TODAY=$(grep -c "^- $TODAY" "$MEM_DIR/trajectories.md" 2>/dev/null || echo 0)
fi
if [[ -f "$MEM_DIR/ignored-skills.md" ]]; then
    IGNORED_TODAY=$(grep -c " | $TODAY" "$MEM_DIR/ignored-skills.md" 2>/dev/null || echo 0)
fi

# No reflexionar si no hubo actividad
TOTAL=$((ERRORS_TODAY + SUCCESS_TODAY + IGNORED_TODAY))
[[ "$TOTAL" -eq 0 ]] && exit 0

# Top 3 skills ignorados acumulado
TOP_IGNORED=""
if [[ -f "$MEM_DIR/ignored-skills.md" ]]; then
    TOP_IGNORED=$(grep -v "^#\|^---\|^Formato\|^Cada vez" "$MEM_DIR/ignored-skills.md" 2>/dev/null | \
        awk -F' \\| ' '{print $1}' | sort | uniq -c | sort -rn | head -3 | \
        awk '{printf "%s(%dx), ", $2, $1}' | sed 's/, $//')
fi

# Últimos errores frecuentes
RECENT_ERRORS=""
if [[ -f "$MEM_DIR/learned.md" ]]; then
    RECENT_ERRORS=$(tail -n 30 "$MEM_DIR/learned.md" 2>/dev/null | grep "Error:" | head -3 | head -c 400)
fi

# Patrones exitosos recientes
RECENT_SUCCESS=""
if [[ -f "$MEM_DIR/trajectories.md" ]]; then
    RECENT_SUCCESS=$(tail -n 15 "$MEM_DIR/trajectories.md" 2>/dev/null | awk -F' \\| ' '{print $2}' | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s(%dx), ", $2, $1}' | sed 's/, $//')
fi

cat >> "$REFLECTIONS_FILE" <<EOF

### $TIMESTAMP

**Actividad hoy**: errores=$ERRORS_TODAY, éxitos=$SUCCESS_TODAY, skills-ignorados=$IGNORED_TODAY

**Skills más ignorados (acum)**: ${TOP_IGNORED:-ninguno}

**Errores recientes**: ${RECENT_ERRORS:-sin datos}

**Patrones exitosos hoy**: ${RECENT_SUCCESS:-sin datos}

**Lección**:
EOF

# Auto-lecciones basadas en heurísticas
if [[ -n "$TOP_IGNORED" ]]; then
    FIRST_IGN=$(echo "$TOP_IGNORED" | awk -F'(' '{print $1}')
    echo "- Skill '$FIRST_IGN' se ignora repetidamente. El router v3 lo marcará OBLIGATORIO la próxima." >> "$REFLECTIONS_FILE"
fi

if [[ "$ERRORS_TODAY" -gt 3 ]]; then
    echo "- Alta tasa de errores hoy ($ERRORS_TODAY). Revisar learned.md antes de comandos similares." >> "$REFLECTIONS_FILE"
fi

if [[ "$SUCCESS_TODAY" -gt "$ERRORS_TODAY" ]] && [[ "$SUCCESS_TODAY" -gt 2 ]]; then
    echo "- Sesión productiva: $SUCCESS_TODAY éxitos registrados. Las trayectorias están disponibles en trajectories.md." >> "$REFLECTIONS_FILE"
fi

# --------------------------------------------------------
# Destilación: cada 5 reflexiones, promover a patterns.md
# (Reflexion -> ExpeL: episodic -> semantic)
# --------------------------------------------------------
REFL_COUNT=$(grep -c "^### " "$REFLECTIONS_FILE" 2>/dev/null || echo 0)
if [[ $((REFL_COUNT % 5)) -eq 0 ]] && [[ "$REFL_COUNT" -gt 0 ]]; then
    echo "" >> "$PATTERNS_FILE"
    echo "## Destilado $TIMESTAMP (reflexión #$REFL_COUNT)" >> "$PATTERNS_FILE"

    # Extraer skills con ratio ignored/used alto
    if [[ -f "$MEM_DIR/skill-stats.json" ]]; then
        PROBLEMATIC=$(jq -r 'to_entries | map(select(.value.ignored >= 3)) | .[0:3] | map("- Skill `\(.key)`: ignorado \(.value.ignored)x, usado \(.value.used // 0)x. Forzar uso cuando aparezca en sugerencias.") | .[]' "$MEM_DIR/skill-stats.json" 2>/dev/null || echo "")
        [[ -n "$PROBLEMATIC" ]] && echo "$PROBLEMATIC" >> "$PATTERNS_FILE"
    fi

    # Patrones exitosos frecuentes
    if [[ -f "$MEM_DIR/trajectories.md" ]]; then
        FREQ_PATTERNS=$(grep "^- " "$MEM_DIR/trajectories.md" 2>/dev/null | awk -F' \\| ' '{print $2}' | sort | uniq -c | sort -rn | head -3 | awk '{print "- Signal `" $2 "` ocurrió " $1 " veces. Patrón confiable."}')
        [[ -n "$FREQ_PATTERNS" ]] && echo "$FREQ_PATTERNS" >> "$PATTERNS_FILE"
    fi
fi

# Trim reflections si > 200 entradas
REFL_LINES=$(wc -l < "$REFLECTIONS_FILE")
if [[ "$REFL_LINES" -gt 2000 ]]; then
    HEADER=$(head -n 6 "$REFLECTIONS_FILE")
    TAIL=$(tail -n 1500 "$REFLECTIONS_FILE")
    echo -e "$HEADER\n\n$TAIL" > "$REFLECTIONS_FILE"
fi

exit 0
