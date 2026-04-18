#!/usr/bin/env bash
# shellcheck shell=bash
# -----------------------------------------------------------------------------
# uninstall.sh — complete removal of OmniCoder v4 AND v5 from this machine.
#
# What it removes:
#   v5 artefacts
#     - /usr/local/bin/omnicoder*  (or ~/.local/bin/omnicoder* on Git Bash / user installs)
#     - engram binary in the same prefix
#   v4 artefacts
#     - @qwen-code/qwen-code global npm package
#     - ~/.qwen/
#     - v4 wrapper in ~/.local/bin/omnicoder (if still present)
#     - v4 shell hooks under ~/.omnicoder/hooks/
#   Optional (require flag):
#     --purge-home   remove ~/.omnicoder/ entirely (skills, agents, memory, logs)
#     --purge-config remove ~/.config/opencode/opencode.jsonc
#     --purge-repo   remove the cloned repo $OMNICODER_REPO (default $HOME/omnicoder-v5)
#     --purge-all    equivalent to all three above
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/nicolas2601/omnicoder/main/scripts/uninstall.sh | bash
#
# Works on Linux, macOS, and Git Bash / MSYS / Cygwin on Windows.
# -----------------------------------------------------------------------------
set -euo pipefail

# ---- settings --------------------------------------------------------------
REPO_DIR="${OMNICODER_REPO:-$HOME/omnicoder-v5}"
PURGE_HOME=0
PURGE_CONFIG=0
PURGE_REPO=0
ASSUME_YES=0
if [ ! -t 0 ]; then ASSUME_YES=1; fi   # piped input → auto-yes

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes|-y)       ASSUME_YES=1 ;;
    --purge-home)   PURGE_HOME=1 ;;
    --purge-config) PURGE_CONFIG=1 ;;
    --purge-repo)   PURGE_REPO=1 ;;
    --purge-all)    PURGE_HOME=1; PURGE_CONFIG=1; PURGE_REPO=1 ;;
    -h|--help)
      sed -n '3,22p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---- ui helpers -------------------------------------------------------------
C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_RED=$'\e[31m'; C_GRN=$'\e[32m'
C_YEL=$'\e[33m'; C_RST=$'\e[0m'
if [ ! -t 1 ]; then C_BOLD=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""; C_RST=""; fi
step() { printf '%s▸ %s%s\n' "${C_BOLD}" "$*" "${C_RST}"; }
ok()   { printf '  %s✓%s %s\n' "${C_GRN}" "${C_RST}" "$*"; }
warn() { printf '  %s!%s %s\n' "${C_YEL}" "${C_RST}" "$*"; }
note() { printf '  %s%s%s\n'  "${C_DIM}" "$*" "${C_RST}"; }

ask() {
  prompt=$1
  if [ "$ASSUME_YES" = "1" ]; then return 0; fi
  printf '%s %s[y/N]%s ' "$prompt" "${C_DIM}" "${C_RST}"
  read -r reply
  case ${reply:-} in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# Delete with or without sudo depending on permissions.
safe_rm() {
  target=$1
  [ -e "$target" ] || return 0
  if [ -w "$(dirname "$target")" ] || [ ! -e "$(dirname "$target")" ]; then
    rm -rf -- "$target"
  else
    if command -v sudo >/dev/null 2>&1; then
      sudo rm -rf -- "$target"
    else
      warn "cannot remove $target (no write perms, no sudo)"
      return 1
    fi
  fi
}

# ---- v5 wrappers ------------------------------------------------------------
remove_v5_wrappers() {
  step "Removing v5 wrappers + engram"
  for prefix in /usr/local /opt/homebrew "$HOME/.local"; do
    for f in omnicoder omnicoder.cmd omnicoder.ps1 omnicoder-routing omnicoder-routing.cmd omnicoder-routing.ps1 engram engram.exe; do
      if [ -f "$prefix/bin/$f" ]; then
        safe_rm "$prefix/bin/$f" && ok "removed $prefix/bin/$f"
      fi
    done
  done
}

# ---- v4 artefacts -----------------------------------------------------------
remove_v4() {
  step "Removing v4 artefacts (Qwen Code)"

  # Global npm package.
  if npm ls -g --depth=0 2>/dev/null | grep -q '@qwen-code/qwen-code'; then
    if npm uninstall -g @qwen-code/qwen-code >/dev/null 2>&1; then
      ok "npm uninstall -g @qwen-code/qwen-code"
    else
      warn "npm uninstall failed — try manually: npm uninstall -g @qwen-code/qwen-code"
    fi
  fi

  # Any leftover qwen-code binary.
  if command -v qwen >/dev/null 2>&1; then
    qpath=$(command -v qwen)
    safe_rm "$qpath" && ok "removed $qpath"
  fi

  # ~/.qwen (auth cache + settings).
  if [ -d "$HOME/.qwen" ]; then
    rm -rf "$HOME/.qwen" && ok "removed ~/.qwen"
  fi

  # v4 wrapper (shell script containing "Qwen").
  for candidate in "$HOME/.local/bin/omnicoder" "/usr/local/bin/omnicoder"; do
    if [ -f "$candidate" ] && grep -qE 'Qwen|qwen-code' "$candidate" 2>/dev/null; then
      safe_rm "$candidate" && ok "removed v4 wrapper $candidate"
    fi
  done

  # v4 hooks inside ~/.omnicoder.
  if [ -d "$HOME/.omnicoder/hooks" ]; then
    rm -rf "$HOME/.omnicoder/hooks" && ok "removed ~/.omnicoder/hooks (v4 shell hooks)"
  fi
  for f in install-linux.sh install-windows.bat install-windows.ps1 build-skill-index.sh; do
    [ -f "$HOME/.omnicoder/$f" ] && rm -f "$HOME/.omnicoder/$f" && note "removed ~/.omnicoder/$f"
  done
}

# ---- optional purges --------------------------------------------------------
maybe_purge_home() {
  [ "$PURGE_HOME" = "1" ] || return 0
  step "Purging ~/.omnicoder (full home)"
  if [ -d "$HOME/.omnicoder" ]; then
    ts=$(date +%Y%m%d-%H%M%S)
    backup="$HOME/omnicoder-home-backup-${ts}.tgz"
    tar czf "$backup" -C "$HOME" .omnicoder 2>/dev/null || true
    note "backup: $backup"
    rm -rf "$HOME/.omnicoder" && ok "removed ~/.omnicoder"
  fi
}

maybe_purge_config() {
  [ "$PURGE_CONFIG" = "1" ] || return 0
  step "Purging opencode config"
  for cfg in "$HOME/.config/opencode/opencode.jsonc" \
             "$HOME/.config/opencode/opencode.json" \
             "$APPDATA/opencode/opencode.jsonc"; do
    [ -f "$cfg" ] && rm -f "$cfg" && ok "removed $cfg"
  done
}

maybe_purge_repo() {
  [ "$PURGE_REPO" = "1" ] || return 0
  if [ -d "$REPO_DIR" ]; then
    step "Removing cloned repo $REPO_DIR"
    rm -rf "$REPO_DIR" && ok "removed $REPO_DIR"
  fi
}

# ---- summary ----------------------------------------------------------------
summary() {
  printf '\n%s✓ OmniCoder removed%s\n' "${C_GRN}" "${C_RST}"
  cat <<EOF

  What stayed (on purpose):
    ~/.omnicoder/         (skills, agents, memory, logs)   $( [ "$PURGE_HOME" = "1" ]   && echo "[purged]" )
    ~/.config/opencode/   (Opencode config)                $( [ "$PURGE_CONFIG" = "1" ] && echo "[purged]" )
    $REPO_DIR             (cloned repo)                    $( [ "$PURGE_REPO" = "1" ]   && echo "[purged]" )

  To remove everything, re-run with --purge-all:
    gh api repos/nicolas2601/omnicoder/contents/scripts/uninstall.sh --jq .content | base64 -d | bash -s -- --purge-all

  To reinstall fresh:
    gh api repos/nicolas2601/omnicoder/contents/scripts/setup.sh --jq .content | base64 -d | bash
EOF
}

# ---- main -------------------------------------------------------------------
if ask "Remove OmniCoder v4 and v5 from this system?"; then
  remove_v5_wrappers
  remove_v4
  maybe_purge_home
  maybe_purge_config
  maybe_purge_repo
  summary
else
  echo "aborted"
  exit 0
fi
