#!/bin/sh
# shellcheck shell=sh
# -----------------------------------------------------------------------------
# install.sh — install or uninstall OmniCoder on Linux/macOS.
#
# What it does (idempotent):
#   1. Ensures `opencode` is installed globally via npm.
#   2. Downloads the latest `engram` release (with SHA-256 verify, SEC-05).
#   3. Copies bin/omnicoder* wrappers to $PREFIX/bin (default /usr/local/bin).
#   4. Seeds ~/.omnicoder with agent/ + skills/ from the repo without
#      overwriting user-edited files.
#   5. Seeds ~/.config/opencode/opencode.jsonc only if missing.
#   6. Prints the env-var hint.
#
# Flags:
#   --uninstall     Reverse every step above (asks for confirmation).
#   --prefix DIR    Override install prefix (default /usr/local).
#   --no-sudo       Never attempt sudo; error if permissions insufficient.
#   --yes           Skip interactive confirmations (CI mode).
#
# POSIX sh; lint-clean against `shellcheck --severity=error`.
# -----------------------------------------------------------------------------

set -eu

# ---- defaults ---------------------------------------------------------------
PREFIX="${PREFIX:-/usr/local}"
ASSUME_YES=0
USE_SUDO=1
MODE=install

SCRIPT_DIR=$(cd -P "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd -P "$SCRIPT_DIR/.." && pwd)

OMNICODER_HOME="${OMNICODER_HOME:-$HOME/.omnicoder}"
OPENCODE_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_CFG_FILE="$OPENCODE_CFG_DIR/opencode.jsonc"

ENGRAM_REPO="Gentleman-Programming/engram"
# Pinned SHA-256 digests per platform for SEC-05. Override with
# ENGRAM_SHA256_<PLATFORM> at install time when a new release ships.
ENGRAM_SHA256_LINUX_X64="${ENGRAM_SHA256_LINUX_X64:-}"
ENGRAM_SHA256_LINUX_ARM64="${ENGRAM_SHA256_LINUX_ARM64:-}"
ENGRAM_SHA256_DARWIN_X64="${ENGRAM_SHA256_DARWIN_X64:-}"
ENGRAM_SHA256_DARWIN_ARM64="${ENGRAM_SHA256_DARWIN_ARM64:-}"

# ---- helpers ----------------------------------------------------------------
log()  { printf '[install] %s\n' "$*"; }
warn() { printf '[install] WARN: %s\n' "$*" >&2; }
die()  { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

confirm() {
  if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
  printf '%s [y/N] ' "$1"
  read -r answer
  case ${answer:-} in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

runas_root() {
  # Write targets often live in /usr/local/bin. Only escalate if needed.
  if [ -w "$1" ]; then
    shift
    "$@"
    return $?
  fi
  if [ "$USE_SUDO" -eq 0 ]; then
    die "no write permission for $1 and --no-sudo set"
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    die "no write permission for $1 and sudo not available"
  fi
  shift
  sudo "$@"
}

detect_platform() {
  uname_s=$(uname -s 2>/dev/null || echo unknown)
  uname_m=$(uname -m 2>/dev/null || echo unknown)
  case "$uname_s" in
    Linux)  os=linux ;;
    Darwin) os=darwin ;;
    *) die "unsupported OS: $uname_s" ;;
  esac
  case "$uname_m" in
    x86_64|amd64) arch=x64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) die "unsupported arch: $uname_m" ;;
  esac
  printf '%s-%s\n' "$os" "$arch"
}

# ---- arg parse --------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case $1 in
    --uninstall) MODE=uninstall ;;
    --prefix)    shift; PREFIX=${1:?--prefix needs an argument} ;;
    --prefix=*)  PREFIX=${1#--prefix=} ;;
    --no-sudo)   USE_SUDO=0 ;;
    --yes|-y)    ASSUME_YES=1 ;;
    -h|--help)
      sed -n '3,22p' "$0"
      exit 0
      ;;
    *) die "unknown flag: $1" ;;
  esac
  shift
done

BIN_DIR="$PREFIX/bin"

# ---- step: opencode ---------------------------------------------------------
install_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    log "opencode already installed: $(command -v opencode)"
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    die "npm not found; install Node.js 18+ first"
  fi
  log "installing opencode-ai globally via npm"
  npm install -g opencode-ai@latest
}

# ---- step: engram -----------------------------------------------------------
install_engram() {
  if command -v engram >/dev/null 2>&1; then
    log "engram already installed: $(command -v engram)"
    return 0
  fi

  platform=$(detect_platform)
  log "downloading engram ($platform) latest release"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  # Prefer gh (handles auth + private assets gracefully).
  asset_pattern=""
  case $platform in
    linux-x64)    asset_pattern="engram*linux*x86_64*"; sha_var=$ENGRAM_SHA256_LINUX_X64 ;;
    linux-arm64)  asset_pattern="engram*linux*aarch64*"; sha_var=$ENGRAM_SHA256_LINUX_ARM64 ;;
    darwin-x64)   asset_pattern="engram*darwin*x86_64*"; sha_var=$ENGRAM_SHA256_DARWIN_X64 ;;
    darwin-arm64) asset_pattern="engram*darwin*aarch64*"; sha_var=$ENGRAM_SHA256_DARWIN_ARM64 ;;
  esac

  if command -v gh >/dev/null 2>&1; then
    ( cd "$tmp" && gh release download --repo "$ENGRAM_REPO" \
        --pattern "$asset_pattern" 2>/dev/null ) || warn "gh download failed; falling back to curl"
  fi

  # curl fallback
  if ! ls "$tmp"/* >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1; then
      die "neither gh nor curl available; cannot fetch engram"
    fi
    api="https://api.github.com/repos/$ENGRAM_REPO/releases/latest"
    url=$(curl -fsSL "$api" \
      | grep -E '"browser_download_url":' \
      | grep -E "$(echo "$asset_pattern" | sed 's/\*/.*/g')" \
      | head -n1 \
      | sed -E 's/.*"browser_download_url":[[:space:]]*"([^"]+)".*/\1/')
    [ -n "${url:-}" ] || die "could not resolve engram download URL"
    log "fetching $url"
    curl -fsSL \
      -H "Accept: application/octet-stream" \
      -o "$tmp/engram.asset" "$url"
  fi

  asset=$(ls "$tmp"/engram* 2>/dev/null | head -n1)
  [ -n "${asset:-}" ] && [ -f "$asset" ] || die "engram asset missing after download"

  # SHA-256 verification (SEC-05). If digest is pinned, enforce it.
  if [ -n "${sha_var:-}" ]; then
    actual=""
    if command -v sha256sum >/dev/null 2>&1; then
      actual=$(sha256sum "$asset" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
      actual=$(shasum -a 256 "$asset" | awk '{print $1}')
    else
      die "no sha256sum/shasum available for SHA-256 verification"
    fi
    if [ "$actual" != "$sha_var" ]; then
      die "engram SHA-256 mismatch: expected $sha_var, got $actual"
    fi
    log "engram SHA-256 verified"
  else
    warn "ENGRAM_SHA256 not pinned for $platform — skipping digest verification (set ENGRAM_SHA256_* to enforce)"
  fi

  # Extract if tarball/zip, else assume raw binary.
  case $asset in
    *.tar.gz|*.tgz) ( cd "$tmp" && tar -xzf "$asset" ) ;;
    *.zip)          ( cd "$tmp" && unzip -q "$asset" ) ;;
  esac

  bin_found=$(find "$tmp" -type f -name 'engram' -perm -u+x 2>/dev/null | head -n1)
  if [ -z "$bin_found" ]; then
    # raw binary case
    bin_found=$asset
  fi
  chmod +x "$bin_found"
  runas_root "$BIN_DIR" install -m 0755 "$bin_found" "$BIN_DIR/engram"
  log "engram installed to $BIN_DIR/engram"
}

# ---- step: wrappers ---------------------------------------------------------
install_wrappers() {
  [ -d "$BIN_DIR" ] || runas_root "$PREFIX" mkdir -p "$BIN_DIR"
  for f in omnicoder omnicoder.cmd omnicoder.ps1; do
    src="$REPO_ROOT/bin/$f"
    [ -f "$src" ] || { warn "missing $src"; continue; }
    dst="$BIN_DIR/$f"
    log "installing $dst"
    runas_root "$BIN_DIR" install -m 0755 "$src" "$dst"
  done
}

# ---- step: home -------------------------------------------------------------
seed_home() {
  mkdir -p "$OMNICODER_HOME"
  # copy packages/omnicoder/package.json so wrappers can read the version
  if [ -f "$REPO_ROOT/packages/omnicoder/package.json" ]; then
    cp -f "$REPO_ROOT/packages/omnicoder/package.json" "$OMNICODER_HOME/package.json"
  fi

  # Idempotent copy: only populate missing files. A user who edited an agent
  # keeps their version. New upstream agents show up, existing ones do not
  # get overwritten.
  for sub in agent skills; do
    src="$REPO_ROOT/.opencode/$sub"
    dst="$OMNICODER_HOME/$sub"
    [ -d "$src" ] || continue
    mkdir -p "$dst"
    # POSIX find: walk every regular file under $src, compute its relative
    # path, and only copy if the destination is absent.
    ( cd "$src" && find . -type f -print ) | while IFS= read -r rel; do
      target="$dst/${rel#./}"
      if [ ! -f "$target" ]; then
        mkdir -p "$(dirname "$target")"
        cp "$src/${rel#./}" "$target"
      fi
    done
  done
  log "seeded $OMNICODER_HOME (non-destructive)"
}

seed_opencode_config() {
  mkdir -p "$OPENCODE_CFG_DIR"
  if [ -f "$OPENCODE_CFG_FILE" ]; then
    log "opencode config exists at $OPENCODE_CFG_FILE (respecting user overrides)"
    return 0
  fi
  if [ -f "$REPO_ROOT/.omnicoder/opencode.jsonc" ]; then
    cp "$REPO_ROOT/.omnicoder/opencode.jsonc" "$OPENCODE_CFG_FILE"
    log "seeded $OPENCODE_CFG_FILE"
  fi
}

# ---- step: uninstall --------------------------------------------------------
do_uninstall() {
  if ! confirm "Uninstall OmniCoder from $PREFIX and $OMNICODER_HOME?"; then
    log "aborted"
    exit 0
  fi

  for f in omnicoder omnicoder.cmd omnicoder.ps1 engram; do
    if [ -f "$BIN_DIR/$f" ]; then
      log "removing $BIN_DIR/$f"
      runas_root "$BIN_DIR" rm -f "$BIN_DIR/$f"
    fi
  done

  if [ -d "$OMNICODER_HOME" ]; then
    if confirm "Remove $OMNICODER_HOME (includes agents/skills/config)?"; then
      rm -rf "$OMNICODER_HOME"
      log "removed $OMNICODER_HOME"
    fi
  fi

  if [ -f "$OPENCODE_CFG_FILE" ]; then
    if confirm "Remove seeded opencode config at $OPENCODE_CFG_FILE?"; then
      rm -f "$OPENCODE_CFG_FILE"
    fi
  fi

  log "uninstall complete (opencode-ai/npm kept — remove manually if desired)"
}

# ---- post-install hint ------------------------------------------------------
print_hints() {
  cat <<'HINT'

[install] done.

Next steps — set at least one provider key before running `omnicoder`:

  export NVIDIA_API_KEY=...       # MiniMax M2.7 / Qwen 3 Coder on NIM
  export MINIMAX_API_KEY=...      # MiniMax direct (Anthropic-compat)
  export DASHSCOPE_API_KEY=...    # Alibaba Qwen Max
  export ANTHROPIC_API_KEY=...    # Claude
  export OPENAI_API_KEY=...       # OpenAI

Then:
  omnicoder doctor       # health check
  omnicoder              # launch the TUI
HINT
}

# ---- main -------------------------------------------------------------------
main() {
  if [ "$MODE" = "uninstall" ]; then
    do_uninstall
    return 0
  fi

  log "OmniCoder install -> prefix=$PREFIX, home=$OMNICODER_HOME"
  install_opencode
  install_engram
  install_wrappers
  seed_home
  seed_opencode_config
  print_hints
}

main
