#!/usr/bin/env bash
# ============================================================
# OmniCoder - PostTool Dispatcher (consolidado, v4.3)
#
# Reemplaza 6 hooks separados (post-tool-logger, error-learner,
# success-learner, skill-usage-tracker, causal-learner, token-tracker)
# con un solo proceso que parsea el INPUT una vez y dispatcha a
# funciones internas. Reduce latencia por tool-call de ~340ms a ~50ms.
#
# Filosofia:
#   - Logging/learning NUNCA deben bloquear el siguiente LLM call
#   - Los aprendizajes se ejecutan en background (&) despues del exit
#   - Solo provider-failover queda separado (emite additionalContext critico)
# ============================================================
set -euo pipefail
trap 'echo "{}"; exit 0' ERR

# Portable lock helper (flock on Linux/macOS, mkdir fallback on Git Bash Windows)
# shellcheck source=_flock-compat.sh
. "$(dirname "${BASH_SOURCE[0]}")/_flock-compat.sh" 2>/dev/null || true

INPUT=$(cat)

# --- v4.4: Parse en UNA sola jq call (antes 6 jq = 6 forks = ~30ms). ---
# Formato TSV con base64 para TOOL_INPUT/TOOL_RESPONSE (pueden tener tabs/newlines).
_PARSE=$(echo "$INPUT" | jq -r '[
    (.tool_name // ""),
    ((.tool_input // {}) | @json | @base64),
    ((.tool_response // "") | tostring | @base64),
    ((if (.tool_response | type) == "object" then (.tool_response.exit_code // 0) else 0 end) | tostring),
    (.session_id // "unknown"),
    (.cwd // "")
] | @tsv' 2>/dev/null || printf '\t\t\t0\tunknown\t')

IFS=$'\t' read -r TOOL_NAME TOOL_INPUT_B64 TOOL_RESPONSE_B64 EXIT_CODE SESSION_ID CWD <<< "$_PARSE"
TOOL_INPUT=$(echo "$TOOL_INPUT_B64" | base64 -d 2>/dev/null || echo "{}")
TOOL_RESPONSE=$(echo "$TOOL_RESPONSE_B64" | base64 -d 2>/dev/null || echo "")
[[ -z "$CWD" ]] && CWD="$PWD"

LOG_DIR="$HOME/.omnicoder/logs"
MEM_DIR="$HOME/.omnicoder/memory"
CACHE_DIR="$HOME/.omnicoder/.cache"
mkdir -p "$LOG_DIR" "$MEM_DIR" "$CACHE_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TS_ISO=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

# ============================================================
# 1. LOGGING (rapido, sync) - 1-linea por operacion
# ============================================================
echo "${TIMESTAMP}|${SESSION_ID}|${TOOL_NAME}|${CWD}" >> "$LOG_DIR/operations.log"

# Rotar log > 10MB
LOG_FILE="$LOG_DIR/operations.log"
LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
if [[ "$LOG_SIZE" -gt 10485760 ]]; then
    mv "$LOG_FILE" "$LOG_FILE.$(date '+%Y%m%d')" 2>/dev/null || true
    : > "$LOG_FILE"
fi

# ============================================================
# 1b. PROVIDER FAILOVER DETECTION (v4.4 consolidado)
# Antes era un hook separado (provider-failover.sh). Ahora reutilizamos
# TOOL_RESPONSE ya parseado y solo pagamos costo si hay sintomas.
# Emite additionalContext via stdout (JSON unico al final).
# ============================================================
FAILOVER_CTX=""
if [[ -n "$TOOL_RESPONSE" ]]; then
    FAILOVER_RE='429|rate.?limit|too many requests|503|service.?unavailable|timed?\s*out|ETIMEDOUT|ECONNREFUSED|ECONNRESET|connection.*refused|401|unauthorized|invalid.*key'
    if MATCH=$(echo "$TOOL_RESPONSE" | head -c 4096 | grep -oiE "$FAILOVER_RE" | head -1); then
        if [[ -n "$MATCH" ]]; then
            REASON="Fallo provider detectado ($MATCH)"
            echo "[$TS_ISO] PROVIDER FAILURE: $REASON" >> "$LOG_DIR/provider-failures.log"
            # Count recent (last 5 min) sin spawn awk: solo grep simple sobre tail
            RECENT_COUNT=$(tail -n 100 "$LOG_DIR/provider-failures.log" 2>/dev/null | grep -c "PROVIDER FAILURE" 2>/dev/null || echo 0)
            RECENT_COUNT=$(echo "${RECENT_COUNT:-0}" | head -n1 | tr -cd '0-9')
            FAILOVER_CTX="[PROVIDER-ISSUE] $REASON detectado."
            if [[ "${RECENT_COUNT:-0}" -ge 3 ]]; then
                FAILOVER_CTX="$FAILOVER_CTX Multiples fallas recientes ($RECENT_COUNT). Considera cambiar provider: bash ~/.omnicoder/scripts/switch-provider.sh <provider>"
            fi
        fi
    fi
fi

# ============================================================
# 2. TODO LO DEMAS en background (NO bloquea el LLM call)
# ============================================================
# Usamos un subshell en bg + setsid para que sobreviva al exit del hook.
(
    # Evitar propagar errores del bg a la shell principal
    set +e

    # --------------------------------------------------------
    # 2a. TOKEN TRACKER (estima tokens del output)
    # --------------------------------------------------------
    OUTPUT_LEN=${#TOOL_RESPONSE}
    EST_TOKENS=$(( OUTPUT_LEN / 4 ))
    USAGE_FILE="$LOG_DIR/token-usage.jsonl"
    echo "{\"ts\":\"$TS_ISO\",\"tool\":\"$TOOL_NAME\",\"est_tokens\":$EST_TOKENS,\"chars\":$OUTPUT_LEN}" >> "$USAGE_FILE" 2>/dev/null

    # Rotar token log
    if [[ -f "$USAGE_FILE" ]]; then
        LC=$(wc -l < "$USAGE_FILE" 2>/dev/null || echo 0)
        if [[ "$LC" -gt 10000 ]]; then
            tail -n 5000 "$USAGE_FILE" > "$USAGE_FILE.tmp" && mv "$USAGE_FILE.tmp" "$USAGE_FILE"
        fi
    fi

    # --------------------------------------------------------
    # 2b. ERROR LEARNER
    # --------------------------------------------------------
    IS_ERROR=0
    if [[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]]; then
        IS_ERROR=1
    elif echo "$TOOL_RESPONSE" | grep -qiE '(command not found|permission denied|no such file|syntaxerror|typeerror|modulenotfound|cannot find module|fatal:|error:|failed to)' 2>/dev/null; then
        IS_ERROR=1
    fi

    if [[ "$IS_ERROR" == "1" ]]; then
        LEARNED_FILE="$MEM_DIR/learned.md"
        if [[ ! -f "$LEARNED_FILE" ]]; then
            cat > "$LEARNED_FILE" <<'EOF'
# Errores Aprendidos

Registro automatico de errores. Dedup por md5. Ultimas 1000 entradas.

---
EOF
        fi

        TARGET=""
        case "$TOOL_NAME" in
            Bash)
                TARGET=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null | head -c 200)
                ;;
            Edit|Write|Read)
                TARGET=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null)
                ;;
        esac
        ERROR_SNIPPET=$(echo "$TOOL_RESPONSE" | tr '\n' ' ' | head -c 300)
        SIG=$(echo "${TARGET}${ERROR_SNIPPET}" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "")

        if [[ -n "$SIG" ]] && ! grep -q "sig:$SIG" "$LEARNED_FILE" 2>/dev/null; then
            if command -v oc_locked_heredoc >/dev/null 2>&1; then
                oc_locked_heredoc "$LEARNED_FILE" <<EOF

### $TS_ISO | $TOOL_NAME
- **Target**: \`$TARGET\`
- **Error**: $ERROR_SNIPPET
- sig:$SIG
EOF
            else
                (flock -w 2 200; cat >> "$LEARNED_FILE" <<EOF

### $TS_ISO | $TOOL_NAME
- **Target**: \`$TARGET\`
- **Error**: $ERROR_SNIPPET
- sig:$SIG
EOF
                ) 200>"$LEARNED_FILE.lock"
            fi

            # Trim > 2500 lineas
            LC=$(wc -l < "$LEARNED_FILE" 2>/dev/null || echo 0)
            if [[ "$LC" -gt 2500 ]]; then
                _trim_learned() {
                    HEADER=$(head -n 7 "$LEARNED_FILE")
                    TAIL=$(tail -n 1000 "$LEARNED_FILE")
                    printf '%s\n\n%s\n' "$HEADER" "$TAIL" > "$LEARNED_FILE"
                }
                if command -v oc_with_lock >/dev/null 2>&1; then
                    oc_with_lock "$LEARNED_FILE" _trim_learned
                else
                    (flock -w 2 200; _trim_learned) 200>"$LEARNED_FILE.lock"
                fi
            fi
        fi
    fi

    # --------------------------------------------------------
    # 2c. SUCCESS LEARNER (solo Bash exitoso con signal)
    # --------------------------------------------------------
    if [[ "$TOOL_NAME" == "Bash" ]] && { [[ "$EXIT_CODE" == "0" ]] || [[ "$EXIT_CODE" == "null" ]]; }; then
        CMD=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null | head -c 300)
        SIGNAL=""
        if echo "$CMD" | grep -qE '(npm test|pytest|go test|cargo test|jest|vitest)' 2>/dev/null; then
            echo "$TOOL_RESPONSE" | grep -qiE '(pass|ok|success|[0-9]+ passed|tests? passed)' 2>/dev/null && SIGNAL="tests-pass"
        elif echo "$CMD" | grep -qE '(npm run build|cargo build|go build|tsc|vite build|next build)' 2>/dev/null; then
            echo "$TOOL_RESPONSE" | grep -qiE '(error|failed)' 2>/dev/null || SIGNAL="build-ok"
        elif echo "$CMD" | grep -qE '^git commit' 2>/dev/null; then
            SIGNAL="commit"
        elif echo "$CMD" | grep -qE '(npm run lint|eslint|ruff|clippy)' 2>/dev/null; then
            echo "$TOOL_RESPONSE" | grep -qiE '(error|[0-9]+ problems?)' 2>/dev/null || SIGNAL="lint-clean"
        fi

        if [[ -n "$SIGNAL" ]]; then
            TRAJ_FILE="$MEM_DIR/trajectories.md"
            if [[ ! -f "$TRAJ_FILE" ]]; then
                cat > "$TRAJ_FILE" <<'EOF'
# Trayectorias Exitosas

Formato: TIMESTAMP | SIGNAL | TOOL | SNIPPET

---
EOF
            fi
            SNIPPET=$(echo "$CMD" | head -c 150)
            SIG=$(echo "${SIGNAL}${SNIPPET}" | md5sum 2>/dev/null | cut -d' ' -f1)
            RECENT=$(tail -n 20 "$TRAJ_FILE" 2>/dev/null)
            if ! echo "$RECENT" | grep -q "sig:$SIG" 2>/dev/null; then
                TRAJ_LINE="- $TS_ISO | $SIGNAL | $TOOL_NAME | \`$SNIPPET\` | cwd:$CWD | sig:$SIG"
                if command -v oc_locked_append >/dev/null 2>&1; then
                    oc_locked_append "$TRAJ_FILE" "$TRAJ_LINE"
                else
                    (flock -w 2 200; printf '%s\n' "$TRAJ_LINE" >> "$TRAJ_FILE") 200>"$TRAJ_FILE.lock"
                fi

                LC=$(wc -l < "$TRAJ_FILE" 2>/dev/null || echo 0)
                if [[ "$LC" -gt 600 ]]; then
                    _trim_traj_disp() {
                        HEADER=$(head -n 7 "$TRAJ_FILE")
                        TAIL=$(tail -n 500 "$TRAJ_FILE")
                        printf '%s\n\n%s\n' "$HEADER" "$TAIL" > "$TRAJ_FILE"
                    }
                    if command -v oc_with_lock >/dev/null 2>&1; then
                        oc_with_lock "$TRAJ_FILE" _trim_traj_disp
                    else
                        (flock -w 2 200; _trim_traj_disp) 200>"$TRAJ_FILE.lock"
                    fi
                fi
            fi
        fi
    fi

    # --------------------------------------------------------
    # 2d. CAUSAL LEARNER (solo Bash, buffer entre ejecuciones)
    # --------------------------------------------------------
    if [[ "$TOOL_NAME" == "Bash" ]]; then
        BUFFER="$CACHE_DIR/tool-buffer.json"
        CMD=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null | head -c 200)
        if [[ -n "$CMD" ]]; then
            CMD_HEAD=$(echo "$CMD" | awk '{print $1}' | xargs basename 2>/dev/null || echo "")
            if [[ "$CMD_HEAD" =~ ^(npm|yarn|pnpm|npx)$ ]]; then
                CMD_HEAD="$CMD_HEAD $(echo "$CMD" | awk '{print $2, $3}')"
            fi

            STATUS="ok"
            { [[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]]; } && STATUS="fail"
            echo "$TOOL_RESPONSE" | head -c 200 | grep -qiE '(command not found|no such file|permission denied|fatal:|error:)' 2>/dev/null && STATUS="fail"

            NOW=$(date +%s)
            PREV_CMD=""; PREV_STATUS=""; PREV_TS=0
            if [[ -f "$BUFFER" ]]; then
                PREV_CMD=$(jq -r '.cmd // ""' "$BUFFER" 2>/dev/null)
                PREV_STATUS=$(jq -r '.status // ""' "$BUFFER" 2>/dev/null)
                PREV_TS=$(jq -r '.ts // 0' "$BUFFER" 2>/dev/null)
            fi

            jq -n --arg cmd "$CMD_HEAD" --arg status "$STATUS" --arg full "$CMD" --argjson ts "$NOW" \
                '{cmd:$cmd, status:$status, full:$full, ts:$ts}' > "$BUFFER"

            if [[ "$PREV_STATUS" == "fail" ]] && [[ "$STATUS" == "ok" ]]; then
                GAP=$((NOW - PREV_TS))
                if [[ "$GAP" -gt 0 ]] && [[ "$GAP" -lt 120 ]]; then
                    PREV_FIRST=$(echo "$PREV_CMD" | awk '{print $1}')
                    CURR_FIRST=$(echo "$CMD_HEAD" | awk '{print $1}')
                    if [[ "$PREV_FIRST" == "$CURR_FIRST" ]] || { [[ -n "$PREV_FIRST" ]] && [[ "$CMD" == *"$PREV_FIRST"* ]]; }; then
                        CAUSAL_FILE="$MEM_DIR/causal-edges.md"
                        if [[ ! -f "$CAUSAL_FILE" ]]; then
                            cat > "$CAUSAL_FILE" <<'EOF'
# Causal Edges (Si X falla -> probar Y)

---
EOF
                        fi
                        SIG=$(echo "${PREV_CMD}${CMD_HEAD}" | md5sum | cut -d' ' -f1)
                        if ! grep -q "sig:$SIG" "$CAUSAL_FILE" 2>/dev/null; then
                            CAUSAL_LINE="- Si falla \`$PREV_CMD\` -> probar \`$CMD_HEAD\` ($TS_ISO) sig:$SIG"
                            if command -v oc_locked_append >/dev/null 2>&1; then
                                oc_locked_append "$CAUSAL_FILE" "$CAUSAL_LINE"
                            else
                                (flock -w 2 200; printf '%s\n' "$CAUSAL_LINE" >> "$CAUSAL_FILE") 200>"$CAUSAL_FILE.lock"
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi

    # --------------------------------------------------------
    # 2e. SKILL USAGE TRACKER (detecta si se uso la skill sugerida)
    # --------------------------------------------------------
    SUGG_LOG="$CACHE_DIR/last-suggestion.json"
    if [[ -f "$SUGG_LOG" ]]; then
        SUGG_SKILL=$(jq -r '.skill // ""' "$SUGG_LOG" 2>/dev/null)
        SUGG_SCORE=$(jq -r '.skill_score // 0' "$SUGG_LOG" 2>/dev/null)
        SUGG_LEVEL=$(jq -r '.level // ""' "$SUGG_LOG" 2>/dev/null)
        SUGG_TS=$(jq -r '.ts // ""' "$SUGG_LOG" 2>/dev/null)

        if [[ -n "$SUGG_SKILL" ]] && [[ "$SUGG_SCORE" -ge 3 ]]; then
            USED=0
            if [[ "$TOOL_NAME" == "Read" ]]; then
                FP=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null)
                if [[ "$FP" == *"/skills/$SUGG_SKILL/"* ]] || [[ "$FP" == *"/skills/$SUGG_SKILL.md" ]]; then
                    USED=1
                fi
            fi
            if [[ "$TOOL_NAME" == "Bash" ]]; then
                CMD2=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null)
                echo "$CMD2" | grep -q "$SUGG_SKILL" 2>/dev/null && USED=1
            fi

            STATS_FILE="$MEM_DIR/skill-stats.json"
            [[ ! -f "$STATS_FILE" ]] && echo '{}' > "$STATS_FILE"

            if [[ "$USED" == "1" ]]; then
                rm -f "$SUGG_LOG"
                _bump_used_disp() {
                    jq --arg s "$SUGG_SKILL" '.[$s] = ((.[$s] // {used:0, ignored:0}) | .used += 1)' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE" 2>/dev/null
                }
                if command -v oc_with_lock >/dev/null 2>&1; then
                    oc_with_lock "$STATS_FILE" _bump_used_disp
                else
                    (flock -w 2 200; _bump_used_disp) 200>"$STATS_FILE.lock"
                fi
            else
                NOW=$(date +%s)
                SUG_EPOCH=$(date -d "$SUGG_TS" +%s 2>/dev/null || echo "$NOW")
                ELAPSED=$((NOW - SUG_EPOCH))
                if [[ "$ELAPSED" -gt 30 ]] && [[ "$TOOL_NAME" =~ ^(Bash|Edit|Write)$ ]]; then
                    IGNORED_FILE="$MEM_DIR/ignored-skills.md"
                    if [[ ! -f "$IGNORED_FILE" ]]; then
                        cat > "$IGNORED_FILE" <<'EOF'
# Skills Ignorados

Formato: NOMBRE | TIMESTAMP | SCORE | LEVEL | PROMPT_SNIPPET

---
EOF
                    fi
                    PROMPT_SNIP=$(jq -r '.prompt // ""' "$SUGG_LOG" 2>/dev/null | head -c 100)
                    IGN_LINE_D="$SUGG_SKILL | $TS_ISO | $SUGG_SCORE | $SUGG_LEVEL | $PROMPT_SNIP"
                    if command -v oc_locked_append >/dev/null 2>&1; then
                        oc_locked_append "$IGNORED_FILE" "$IGN_LINE_D"
                    else
                        (flock -w 2 200; printf '%s\n' "$IGN_LINE_D" >> "$IGNORED_FILE") 200>"$IGNORED_FILE.lock"
                    fi
                    _bump_ignored_disp() {
                        jq --arg s "$SUGG_SKILL" '.[$s] = ((.[$s] // {used:0, ignored:0}) | .ignored += 1)' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE" 2>/dev/null
                    }
                    if command -v oc_with_lock >/dev/null 2>&1; then
                        oc_with_lock "$STATS_FILE" _bump_ignored_disp
                    else
                        (flock -w 2 200; _bump_ignored_disp) 200>"$STATS_FILE.lock"
                    fi
                    rm -f "$SUGG_LOG"
                fi
            fi
        fi
    fi
) >/dev/null 2>&1 &
disown 2>/dev/null || true

# v4.4: Si hubo failover detectado, emitir context. Sino {}.
if [[ -n "$FAILOVER_CTX" ]]; then
    jq -n --arg msg "$FAILOVER_CTX" '{"hookSpecificOutput":{"additionalContext":$msg}}'
else
    echo '{}'
fi
exit 0
