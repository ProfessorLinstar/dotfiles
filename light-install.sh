#!/bin/bash

################################################################################
# Program: light-install.sh
# Description: Lightweight terminal setup for any Linux/macOS system.
#              Configures shell aliases, installs tmux plugins, and optionally
#              installs neovim/tmux from GitHub releases without a package manager.
# Location: ~/dotfiles/light-install.sh
################################################################################

set -euo pipefail

DOTFILES_ROOT="$HOME/dotfiles"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"

# --- Output helpers ---
info()  { printf '\033[32m[info]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Lightweight terminal setup script. All operations are idempotent.

Options:
  -s, --shell       Configure shell keybindings (source aliases in shell rc)
  -t, --tmux        Install tmux plugin manager and plugins
  -i, --install     Install neovim and tmux to ~/.local/bin from GitHub
  -a, --all         Run all of the above
  -h, --help        Show this help message
EOF
}

# --- Flag parsing ---
DO_SHELL=false
DO_TMUX=false
DO_INSTALL=false

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--shell)   DO_SHELL=true;   shift ;;
    -t|--tmux)    DO_TMUX=true;    shift ;;
    -i|--install) DO_INSTALL=true; shift ;;
    -a|--all)     DO_SHELL=true; DO_TMUX=true; DO_INSTALL=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# --- Platform detection ---
detect_os_arch() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  case "$OS" in
    Linux)  OS=linux ;;
    Darwin) OS=macos ;;
    *)      error "Unsupported OS: $OS" ;;
  esac
  case "$ARCH" in
    x86_64)        ARCH=x86_64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *)             error "Unsupported architecture: $ARCH" ;;
  esac
}

# Fetch the browser_download_url for a GitHub release asset matching a pattern.
# Prefers `gh` CLI (authenticated, higher rate limit) and falls back to curl.
# Usage: github_release_url <owner/repo> <grep-pattern>
github_release_url() {
  local repo="$1" pattern="$2" json
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    json="$(gh api "repos/$repo/releases/latest" 2>/dev/null)" || json=""
  fi
  if [[ -z "${json:-}" ]]; then
    json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)" || json=""
  fi
  [[ -n "$json" ]] || { warn "Failed to fetch release info for $repo"; return 1; }
  echo "$json" \
    | grep "browser_download_url" \
    | grep -E "$pattern" \
    | head -1 \
    | cut -d'"' -f4
}

# --- Shell keybindings ---
configure_shell() {
  local source_line="source ~/dotfiles/.config/sh/aliases.sh"
  local shell_name rc_file

  shell_name="$(basename "$SHELL")"
  case "$shell_name" in
    zsh)  rc_file="$HOME/.zshrc" ;;
    bash) rc_file="$HOME/.bashrc" ;;
    *)    warn "Unrecognized shell '$shell_name', defaulting to .bashrc"
          rc_file="$HOME/.bashrc" ;;
  esac

  if [[ ! -f "$rc_file" ]]; then
    info "Creating $rc_file"
    touch "$rc_file"
  fi

  if grep -qF "$source_line" "$rc_file"; then
    info "Shell aliases already configured in $rc_file"
  else
    info "Adding shell aliases to $rc_file"
    printf '\n# Added by light-install.sh\n%s\n' "$source_line" >> "$rc_file"
  fi
}

# --- Tmux plugins ---
install_tmux_plugins() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir" ]]; then
    info "Cloning tpm..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  else
    info "tpm already installed"
  fi

  info "Installing tmux plugins..."
  "$tpm_dir/bin/install_plugins"
}

# --- Install neovim ---
install_neovim() {
  if command -v nvim &>/dev/null; then
    info "neovim already available: $(command -v nvim)"
    return
  fi

  detect_os_arch

  # Use direct GitHub release URL (no API call needed, avoids rate limits).
  # Format: https://github.com/neovim/neovim/releases/latest/download/nvim-<os>-<arch>.tar.gz
  local asset_name
  case "${OS}-${ARCH}" in
    linux-x86_64)  asset_name="nvim-linux-x86_64.tar.gz" ;;
    linux-arm64)   asset_name="nvim-linux-arm64.tar.gz" ;;
    macos-arm64)   asset_name="nvim-macos-arm64.tar.gz" ;;
    macos-x86_64)  asset_name="nvim-macos-x86_64.tar.gz" ;;
    *)             error "No neovim binary available for ${OS}-${ARCH}" ;;
  esac

  local download_url="https://github.com/neovim/neovim/releases/latest/download/${asset_name}"

  local tmp
  tmp="$(mktemp -d)"

  info "Downloading neovim from $download_url ..."
  if ! curl -fSL -o "$tmp/nvim.tar.gz" "$download_url"; then
    warn "Direct download failed, trying GitHub API fallback..."
    local api_pattern="nvim-${OS}.*(${ARCH}|64)\\.tar\\.gz\""
    download_url="$(github_release_url neovim/neovim "$api_pattern")"
    [[ -n "$download_url" ]] || error "Could not find neovim release for ${OS}-${ARCH}"
    curl -fSL -o "$tmp/nvim.tar.gz" "$download_url"
  fi

  info "Extracting to $LOCAL_PREFIX..."
  mkdir -p "$LOCAL_PREFIX"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  # Merge extracted directory contents into ~/.local/
  local extracted_dir
  extracted_dir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"
  cp -r "$extracted_dir"/bin "$LOCAL_PREFIX/"
  cp -r "$extracted_dir"/lib "$LOCAL_PREFIX/" 2>/dev/null || true
  cp -r "$extracted_dir"/share "$LOCAL_PREFIX/"

  rm -rf "$tmp"
  info "neovim installed to $LOCAL_BIN/nvim"
}

# --- Install tmux ---
install_tmux_binary() {
  if command -v tmux &>/dev/null; then
    info "tmux already available: $(command -v tmux)"
    return
  fi

  # tmux only provides source tarballs — we need to build from source.
  local missing=()
  for cmd in gcc make pkg-config; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing build dependencies for tmux: ${missing[*]}
Install them first (e.g. apt install build-essential pkg-config libevent-dev ncurses-dev)."
  fi

  info "Fetching latest tmux release URL..."
  local download_url
  download_url="$(github_release_url tmux/tmux "\\.tar\\.gz\"")"
  [[ -n "$download_url" ]] || error "Could not find tmux release tarball"

  local tmp
  tmp="$(mktemp -d)"

  info "Downloading tmux..."
  curl -fSL -o "$tmp/tmux.tar.gz" "$download_url"

  info "Building tmux (prefix=$LOCAL_PREFIX)..."
  tar -xzf "$tmp/tmux.tar.gz" -C "$tmp"

  local src_dir
  src_dir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"

  (
    cd "$src_dir"
    ./configure --prefix="$LOCAL_PREFIX"
    make
    make install
  )

  rm -rf "$tmp"
  info "tmux installed to $LOCAL_BIN/tmux"
}

# --- Main ---
if $DO_INSTALL; then
  install_neovim
  install_tmux_binary
fi

if $DO_SHELL; then
  configure_shell
fi

if $DO_TMUX; then
  install_tmux_plugins
fi

info "Done."
