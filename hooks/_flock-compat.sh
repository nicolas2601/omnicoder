#!/usr/bin/env bash
# ============================================================
# OmniCoder - flock-compat (shared helper)
#
# Provides a portable `oc_locked_append` and `oc_with_lock`
# that uses `flock` when available (Linux/macOS) and falls
# back to a best-effort lockdir strategy on Git Bash (Windows)
# where `flock(1)` is NOT available.
#
# Race window is small (~ms) and acceptable for append-only
# learning logs. All writers dedupe by md5 signature anyway.
#
# Usage:
#   source "$(dirname "$0")/_flock-compat.sh"
#   oc_locked_append "/path/to/file" "line to append"
#   oc_with_lock "/path/to/file" command arg1 arg2 ...
# ============================================================

# Guard against double-source
[[ -n "${__OC_FLOCK_COMPAT_LOADED:-}" ]] && return 0
__OC_FLOCK_COMPAT_LOADED=1

# Detect flock once per process
if command -v flock >/dev/null 2>&1; then
    __OC_HAS_FLOCK=1
else
    __OC_HAS_FLOCK=0
fi

# ------------------------------------------------------------
# oc_locked_append <file> <content>
#   Appends <content> + newline to <file> under a lock.
#   Creates parent dir if missing.
# ------------------------------------------------------------
oc_locked_append() {
    local file="$1"
    local content="$2"
    local lockfile="${file}.lock"

    mkdir -p "$(dirname "$file")" 2>/dev/null || true

    if [[ "$__OC_HAS_FLOCK" == "1" ]]; then
        (
            flock -w 2 200
            printf '%s\n' "$content" >> "$file"
        ) 200>"$lockfile"
    else
        # Windows / busybox fallback: mkdir-based lock (atomic on most FS).
        # Spin up to ~1s; if we cannot acquire, append anyway (log integrity
        # over perfect ordering; dedupe happens via md5 signatures upstream).
        local lockdir="${file}.lockd"
        local waited=0
        while ! mkdir "$lockdir" 2>/dev/null; do
            sleep 0.05 2>/dev/null || sleep 1
            waited=$((waited + 1))
            if [[ $waited -ge 20 ]]; then break; fi
        done
        printf '%s\n' "$content" >> "$file"
        rmdir "$lockdir" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------
# oc_with_lock <file> <command...>
#   Runs the given command under a lock tied to <file>.
#   The command receives its own stdin/stdout (use with care).
# ------------------------------------------------------------
oc_with_lock() {
    local file="$1"; shift
    local lockfile="${file}.lock"

    mkdir -p "$(dirname "$file")" 2>/dev/null || true

    if [[ "$__OC_HAS_FLOCK" == "1" ]]; then
        (
            flock -w 2 200
            "$@"
        ) 200>"$lockfile"
    else
        local lockdir="${file}.lockd"
        local waited=0
        while ! mkdir "$lockdir" 2>/dev/null; do
            sleep 0.05 2>/dev/null || sleep 1
            waited=$((waited + 1))
            if [[ $waited -ge 20 ]]; then break; fi
        done
        "$@"
        rmdir "$lockdir" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------
# oc_locked_heredoc <file> <<'EOF'
#   ...content...
# EOF
#   Reads stdin and appends it to <file> atomically.
# ------------------------------------------------------------
oc_locked_heredoc() {
    local file="$1"
    local lockfile="${file}.lock"
    local tmp
    tmp="$(mktemp 2>/dev/null || echo "${file}.tmp.$$")"

    cat > "$tmp"
    mkdir -p "$(dirname "$file")" 2>/dev/null || true

    if [[ "$__OC_HAS_FLOCK" == "1" ]]; then
        (
            flock -w 2 200
            cat "$tmp" >> "$file"
        ) 200>"$lockfile"
    else
        local lockdir="${file}.lockd"
        local waited=0
        while ! mkdir "$lockdir" 2>/dev/null; do
            sleep 0.05 2>/dev/null || sleep 1
            waited=$((waited + 1))
            if [[ $waited -ge 20 ]]; then break; fi
        done
        cat "$tmp" >> "$file"
        rmdir "$lockdir" 2>/dev/null || true
    fi
    rm -f "$tmp" 2>/dev/null || true
}

# Export for subshells (bash)
export -f oc_locked_append 2>/dev/null || true
export -f oc_with_lock 2>/dev/null || true
export -f oc_locked_heredoc 2>/dev/null || true
