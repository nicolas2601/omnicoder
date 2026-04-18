#!/usr/bin/env bash
# shellcheck shell=bash
# -----------------------------------------------------------------------------
# setup.sh — one-shot installer for OmniCoder v5.
#
# What it does, in order:
#   1. Detects and optionally backs up OmniCoder v4 (Qwen Code based).
#   2. Removes v4 artefacts: @qwen-code/qwen-code global, v4 wrappers in
#      ~/.local/bin, ~/.qwen/, v4 shell hooks under ~/.omnicoder/hooks/.
#   3. Clones (or refreshes) omnicoder-v5 into ${OMNICODER_REPO:-$HOME/omnicoder-v5}.
#   4. Runs scripts/install.sh --yes (opencode + engram + wrappers + assets).
#   5. Runs `omnicoder doctor` and reports result.
#   6. Optionally runs the tests + benchmark suite for a full QA sweep.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/setup.sh | bash
#
# Flags (via env vars, since we support `curl | bash`):
#   OMNICODER_REPO=<path>     override clone location (default $HOME/omnicoder-v5)
#   OMNICODER_BRANCH=<name>   checkout branch (default main)
#   OMNICODER_NO_V4_PURGE=1   keep v4 artefacts (only upgrade, don't remove)
#   OMNICODER_SKIP_QA=1       skip tests + benchmark at the end (faster)
#   OMNICODER_NON_INTERACTIVE=1   skip all confirmations (default when piped)
# -----------------------------------------------------------------------------
set -euo pipefail

# ---- settings ---------------------------------------------------------------
REPO_URL="https://github.com/nicolas2601/omnicoder.git"
REPO_DIR="${OMNICODER_REPO:-$HOME/omnicoder-v5}"
BRANCH="${OMNICODER_BRANCH:-main}"
NO_V4_PURGE="${OMNICODER_NO_V4_PURGE:-0}"
SKIP_QA="${OMNICODER_SKIP_QA:-0}"
# Piped input → non-interactive by default.
if [ ! -t 0 ]; then
  OMNICODER_NON_INTERACTIVE="${OMNICODER_NON_INTERACTIVE:-1}"
fi
NON_INTERACTIVE="${OMNICODER_NON_INTERACTIVE:-0}"

# ---- ui helpers -------------------------------------------------------------
C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_RED=$'\e[31m'; C_GRN=$'\e[32m'
C_YEL=$'\e[33m'; C_CYN=$'\e[36m'; C_RST=$'\e[0m'
if [ ! -t 1 ]; then C_BOLD=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""; C_CYN=""; C_RST=""; fi

banner() {
  printf '%s' "${C_CYN}"
  cat <<'EOF'

    ___                  _  ____          _
   / _ \ _ __ ___  _ __ (_)/ ___|___   __| | ___ _ __
  | | | | '_ ` _ \| '_ \| | |   / _ \ / _` |/ _ \ '__|
  | |_| | | | | | | | | | | |__| (_) | (_| |  __/ |
   \___/|_| |_| |_|_| |_|_|\____\___/ \__,_|\___|_|    v5.0.0-alpha.1

EOF
  printf '%s' "${C_RST}"
}
step()  { printf '%s▸ %s%s\n' "${C_BOLD}" "$*" "${C_RST}"; }
ok()    { printf '  %s✓%s %s\n' "${C_GRN}" "${C_RST}" "$*"; }
warn()  { printf '  %s!%s %s\n' "${C_YEL}" "${C_RST}" "$*"; }
die()   { printf '  %s✗%s %s\n' "${C_RED}" "${C_RST}" "$*" >&2; exit 1; }
note()  { printf '  %s%s%s\n'  "${C_DIM}" "$*" "${C_RST}"; }

ask() {
  prompt=$1
  if [ "$NON_INTERACTIVE" = "1" ]; then return 0; fi
  printf '%s %s[y/N]%s ' "$prompt" "${C_DIM}" "${C_RST}"
  read -r reply
  case ${reply:-} in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ---- prerequisite check -----------------------------------------------------
check_prereqs() {
  step "Checking prerequisites"
  missing=""
  for cmd in git curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then missing="$missing $cmd"; fi
  done
  if ! command -v node >/dev/null 2>&1; then missing="$missing node"; fi
  if ! command -v npm  >/dev/null 2>&1; then missing="$missing npm"; fi
  if [ -n "$missing" ]; then
    die "missing prerequisites:$missing — install them and re-run"
  fi
  node_major=$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')
  if [ "${node_major:-0}" -lt 18 ]; then
    warn "node $(node -v) detected; 18+ recommended"
  fi
  ok "node $(node -v), npm $(npm -v), git $(git --version | awk '{print $3}')"
}

# ---- v4 detection + purge ---------------------------------------------------
detect_v4() {
  v4_found=0
  v4_reason=""
  if command -v qwen >/dev/null 2>&1; then v4_found=1; v4_reason="${v4_reason}qwen binary, "; fi
  if npm ls -g --depth=0 2>/dev/null | grep -q '@qwen-code/qwen-code'; then
    v4_found=1; v4_reason="${v4_reason}@qwen-code/qwen-code npm, "
  fi
  if [ -d "$HOME/.qwen" ]; then v4_found=1; v4_reason="${v4_reason}~/.qwen dir, "; fi
  # v4 wrapper heuristic: shell script with "Qwen" inside.
  if [ -f "$HOME/.local/bin/omnicoder" ] && grep -qE 'Qwen|qwen-code' "$HOME/.local/bin/omnicoder" 2>/dev/null; then
    v4_found=1; v4_reason="${v4_reason}v4 wrapper ~/.local/bin/omnicoder, "
  fi
  export v4_found v4_reason
}

purge_v4() {
  step "Removing OmniCoder v4"
  ts=$(date +%Y%m%d-%H%M%S)
  backup="$HOME/omnicoder-v4-backup-${ts}.tgz"

  # Backup before destroying anything.
  if [ -d "$HOME/.omnicoder" ] || [ -d "$HOME/.qwen" ]; then
    note "backing up ~/.omnicoder and ~/.qwen → $backup"
    tar czf "$backup" \
      -C "$HOME" \
      $( [ -d "$HOME/.omnicoder" ] && echo .omnicoder ) \
      $( [ -d "$HOME/.qwen" ]      && echo .qwen      ) \
      2>/dev/null || warn "backup had non-fatal errors"
    ok "backup written ($(du -sh "$backup" 2>/dev/null | awk '{print $1}'))"
  fi

  # Remove v4 wrapper from ~/.local/bin if present.
  if [ -f "$HOME/.local/bin/omnicoder" ] && grep -qE 'Qwen|qwen-code' "$HOME/.local/bin/omnicoder" 2>/dev/null; then
    rm -f "$HOME/.local/bin/omnicoder" "$HOME/.local/bin/omnicoder.cmd" "$HOME/.local/bin/omnicoder.ps1" 2>/dev/null || true
    ok "removed v4 wrappers from ~/.local/bin"
  fi

  # Uninstall Qwen Code global.
  if npm ls -g --depth=0 2>/dev/null | grep -q '@qwen-code/qwen-code'; then
    npm uninstall -g @qwen-code/qwen-code >/dev/null 2>&1 && \
      ok "npm uninstall -g @qwen-code/qwen-code" || warn "npm uninstall returned non-zero"
  fi

  # Remove ~/.qwen (auth/cache). Safe because creds are regenerated.
  if [ -d "$HOME/.qwen" ]; then
    rm -rf "$HOME/.qwen" && ok "removed ~/.qwen"
  fi

  # Remove v4 shell hooks; keep ~/.omnicoder/skills, agents, memory.
  if [ -d "$HOME/.omnicoder/hooks" ]; then
    rm -rf "$HOME/.omnicoder/hooks" && ok "removed ~/.omnicoder/hooks (v4 shell hooks)"
  fi
  for f in "$HOME/.omnicoder/install-linux.sh" \
           "$HOME/.omnicoder/install-windows.bat" \
           "$HOME/.omnicoder/install-windows.ps1" \
           "$HOME/.omnicoder/build-skill-index.sh"; do
    [ -f "$f" ] && rm -f "$f" && note "removed $(basename "$f")"
  done

  ok "v4 purge complete (skills, agents, memory preserved)"
  printf '\n  backup: %s\n\n' "$backup"
}

# ---- clone / update v5 repo -------------------------------------------------
clone_or_update() {
  step "Getting omnicoder-v5 at $REPO_DIR (branch $BRANCH)"
  if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR"
    git fetch --quiet origin "$BRANCH" || die "git fetch failed"
    git checkout --quiet "$BRANCH" || die "git checkout $BRANCH failed"
    git reset --quiet --hard "origin/$BRANCH"
    ok "updated to $(git rev-parse --short HEAD)"
  else
    git clone --quiet --branch "$BRANCH" "$REPO_URL" "$REPO_DIR" || die "git clone failed"
    cd "$REPO_DIR"
    ok "cloned $(git rev-parse --short HEAD)"
  fi
}

# ---- run the per-OS installer ----------------------------------------------
run_installer() {
  step "Running scripts/install.sh"
  # Installer handles opencode, engram, wrappers, skills seed. Non-interactive.
  if bash "$REPO_DIR/scripts/install.sh" --yes; then
    ok "installer finished"
  else
    die "installer exited with non-zero"
  fi
}

# ---- verification -----------------------------------------------------------
verify() {
  step "Verifying install"
  if ! command -v omnicoder >/dev/null 2>&1; then
    die "omnicoder not found in PATH — open a new shell and re-run"
  fi
  ver=$(omnicoder --omnicoder-version 2>/dev/null | head -1 | awk '{print $2}')
  ok "omnicoder $ver ready"
  omnicoder doctor >/tmp/omnicoder-doctor.log 2>&1 && ok "doctor: healthy" || \
    warn "doctor reported issues (see /tmp/omnicoder-doctor.log) — usually fixable by exporting an API key"
}

run_qa() {
  if [ "$SKIP_QA" = "1" ]; then
    note "skipping QA (OMNICODER_SKIP_QA=1)"
    return 0
  fi
  if ! command -v bun >/dev/null 2>&1; then
    warn "bun not installed — skipping tests/benchmarks (install with: curl -fsSL https://bun.sh/install | bash)"
    return 0
  fi
  step "Running QA (tests + benchmarks)"
  cd "$REPO_DIR"
  bun install --frozen-lockfile >/dev/null 2>&1 && ok "bun install ok"
  if bun run --cwd packages/omnicoder typecheck >/dev/null 2>&1; then
    ok "typecheck clean"
  else
    warn "typecheck failed — see full logs with: bun run --cwd packages/omnicoder typecheck"
  fi
  test_out=$(bun run --cwd packages/omnicoder test 2>&1 | tail -3 || true)
  echo "$test_out" | sed 's/^/    /'
  if bun run --cwd packages/omnicoder bench/run-all.ts >/tmp/omnicoder-bench.log 2>&1; then
    ok "benchmark completed (full log: /tmp/omnicoder-bench.log)"
    grep -E 'pipeline50|security|memory_bytes' /tmp/omnicoder-bench.log | sed 's/^/    /' || true
  else
    warn "bench failed — see /tmp/omnicoder-bench.log"
  fi
}

# ---- summary ----------------------------------------------------------------
summary() {
  printf '\n%s┌───────────────────────────────────────────────────────┐%s\n' "${C_GRN}" "${C_RST}"
  printf '%s│ OmniCoder v5 is installed. Next steps:                │%s\n' "${C_GRN}" "${C_RST}"
  printf '%s└───────────────────────────────────────────────────────┘%s\n' "${C_GRN}" "${C_RST}"
  cat <<EOF

  1. Export at least one provider API key (any of these):
       export NVIDIA_API_KEY="nvapi-..."
       export MINIMAX_API_KEY="..."
       export DASHSCOPE_API_KEY="..."
       export ANTHROPIC_API_KEY="sk-ant-..."
       export OPENAI_API_KEY="sk-..."

  2. Launch the CLI:
       omnicoder

  3. Re-run setup to upgrade at any time:
       curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/setup.sh | bash

  4. Uninstall completely (v4 + v5):
       curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/uninstall.sh | bash

  Repo:      $REPO_DIR
  Docs:      $REPO_DIR/docs/
  Logs:      ~/.omnicoder/logs/
EOF
}

# ---- main -------------------------------------------------------------------
main() {
  banner
  check_prereqs
  detect_v4
  if [ "$v4_found" = "1" ] && [ "$NO_V4_PURGE" != "1" ]; then
    warn "OmniCoder v4 detected (${v4_reason%, })"
    if ask "Remove v4 and upgrade to v5?"; then
      purge_v4
    else
      note "keeping v4; v5 will install side-by-side — you may need to manage PATH manually"
    fi
  elif [ "$v4_found" = "1" ]; then
    note "v4 detected but OMNICODER_NO_V4_PURGE=1 — keeping v4"
  else
    ok "no v4 install detected"
  fi
  clone_or_update
  run_installer
  verify
  run_qa
  summary
}

main "$@"
