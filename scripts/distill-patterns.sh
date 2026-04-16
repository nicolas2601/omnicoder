#!/usr/bin/env bash
# ============================================================
# OmniCoder - Pattern Distiller (Standalone / Cron)
# Destila trajectories.md + learned.md + reflections.md en
# patterns.md (reglas semanticas reutilizables).
#
# Ejecutar periódicamente (weekly cron) o manualmente:
#   bash ~/.omnicoder/scripts/distill-patterns.sh
#
# Lógica:
#  1. Agrupa trajectories por SIGNAL. Si N >= 3 → patrón confiable.
#  2. Agrupa errores por TARGET. Si repite → "evitar X".
#  3. Agrupa ignored-skills. Si >=3 → "forzar skill X".
#  4. Escribe en patterns.md con timestamp.
# ============================================================
set -euo pipefail

MEM_DIR="$HOME/.omnicoder/memory"
mkdir -p "$MEM_DIR"

PATTERNS_FILE="$MEM_DIR/patterns.md"
TRAJ_FILE="$MEM_DIR/trajectories.md"
LEARNED_FILE="$MEM_DIR/learned.md"
IGNORED_FILE="$MEM_DIR/ignored-skills.md"

if [[ ! -f "$PATTERNS_FILE" ]]; then
    cat > "$PATTERNS_FILE" <<'EOF'
# Patrones Semánticos Destilados

Reglas reusables extraídas automáticamente. Este archivo se carga
en cada SessionStart vía memory-loader.sh.

---

EOF
fi

TIMESTAMP=$(date -Iseconds)
PATTERNS_ADDED=0

echo ""
echo "=== Distill Patterns — $TIMESTAMP ==="

# --------------------------------------------------------
# 1. Trayectorias exitosas frecuentes
# --------------------------------------------------------
if [[ -f "$TRAJ_FILE" ]]; then
    echo "→ Analizando trayectorias..."
    FREQ=$(grep "^- " "$TRAJ_FILE" | awk -F' \\| ' '{print $2}' | sort | uniq -c | sort -rn | awk '$1 >= 3')

    if [[ -n "$FREQ" ]]; then
        echo "" >> "$PATTERNS_FILE"
        echo "## [$TIMESTAMP] Trayectorias confiables" >> "$PATTERNS_FILE"
        while IFS= read -r line; do
            COUNT=$(echo "$line" | awk '{print $1}')
            SIGNAL=$(echo "$line" | awk '{print $2}')
            SIG=$(echo "traj-$SIGNAL" | md5sum | cut -d' ' -f1)
            if ! grep -q "sig:$SIG" "$PATTERNS_FILE" 2>/dev/null; then
                echo "- Signal \`$SIGNAL\` se repitió ${COUNT}x → patrón confiable. Replicar secuencia cuando aparezca contexto similar. sig:$SIG" >> "$PATTERNS_FILE"
                PATTERNS_ADDED=$((PATTERNS_ADDED + 1))
            fi
        done <<< "$FREQ"
    fi
fi

# --------------------------------------------------------
# 2. Errores recurrentes → "evitar"
# --------------------------------------------------------
if [[ -f "$LEARNED_FILE" ]]; then
    echo "→ Analizando errores recurrentes..."
    RECUR=$(grep "Target:" "$LEARNED_FILE" | awk -F'`' '{print $2}' | sort | uniq -c | sort -rn | awk '$1 >= 2' | head -5)

    if [[ -n "$RECUR" ]]; then
        echo "" >> "$PATTERNS_FILE"
        echo "## [$TIMESTAMP] Errores recurrentes a evitar" >> "$PATTERNS_FILE"
        while IFS= read -r line; do
            COUNT=$(echo "$line" | awk '{print $1}')
            TARGET=$(echo "$line" | sed 's/^ *[0-9]* //')
            [[ -z "$TARGET" ]] && continue
            SIG=$(echo "err-$TARGET" | md5sum | cut -d' ' -f1)
            if ! grep -q "sig:$SIG" "$PATTERNS_FILE" 2>/dev/null; then
                SHORT=$(echo "$TARGET" | head -c 80)
                echo "- Evitar: \`$SHORT\` falló ${COUNT}x. Revisar causal-edges.md para alternativas. sig:$SIG" >> "$PATTERNS_FILE"
                PATTERNS_ADDED=$((PATTERNS_ADDED + 1))
            fi
        done <<< "$RECUR"
    fi
fi

# --------------------------------------------------------
# 3. Skills crónicamente ignorados → "forzar"
# --------------------------------------------------------
if [[ -f "$IGNORED_FILE" ]]; then
    echo "→ Analizando skills ignorados..."
    CRON_IGN=$(grep -v "^#\|^---\|^Formato\|^Cada vez" "$IGNORED_FILE" 2>/dev/null | \
        awk -F' \\| ' 'NF>0 {print $1}' | sort | uniq -c | sort -rn | awk '$1 >= 3')

    if [[ -n "$CRON_IGN" ]]; then
        echo "" >> "$PATTERNS_FILE"
        echo "## [$TIMESTAMP] Skills a forzar (ignorados 3+ veces)" >> "$PATTERNS_FILE"
        while IFS= read -r line; do
            COUNT=$(echo "$line" | awk '{print $1}')
            SKILL=$(echo "$line" | awk '{print $2}')
            SIG=$(echo "force-$SKILL" | md5sum | cut -d' ' -f1)
            if ! grep -q "sig:$SIG" "$PATTERNS_FILE" 2>/dev/null; then
                echo "- FORZAR skill \`$SKILL\`: fue ignorado ${COUNT}x pese a score alto. El router v4 lo marca HARD automáticamente. sig:$SIG" >> "$PATTERNS_FILE"
                PATTERNS_ADDED=$((PATTERNS_ADDED + 1))
            fi
        done <<< "$CRON_IGN"
    fi
fi

# --------------------------------------------------------
# 4. Trim: si patterns.md > 1000 lineas, conservar ultimas 800
# --------------------------------------------------------
LINE_COUNT=$(wc -l < "$PATTERNS_FILE")
if [[ "$LINE_COUNT" -gt 1000 ]]; then
    HEADER=$(head -n 6 "$PATTERNS_FILE")
    TAIL=$(tail -n 800 "$PATTERNS_FILE")
    echo -e "$HEADER\n\n$TAIL" > "$PATTERNS_FILE"
    echo "→ patterns.md trimmed (>1000 lines)"
fi

echo "=== Done. $PATTERNS_ADDED nuevos patrones añadidos ==="
echo ""
exit 0
