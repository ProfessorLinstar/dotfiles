#!/bin/bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$HOME/dotfiles"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"

# --- Output helpers ---
info()  { printf '\033[32m[info]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

dotfiles installation and configuration script for Arch Linux.
With no options, runs ./light-install.sh -a (lightweight install).
See README.md for more information.

  --all          install all options
  --terminal     install terminal packages
  --pacman       install pacman packages
  --font         install meslo font for powerlevel10k
  --logiops      install and configure logitech software
  --yay          install yay packages
  --link         create dotfile links
  --services     enable and start custom services
  --manual       make manual substitutions to files in-place
  --tmux         install tmux plugins
  --dconf        load dconf configuration
  --gitconfig    set up default global git config
  --info         provide info on manual configuration tasks
  --xdg          load default xdg configuration
  --printer      install and set up HP printer drivers
  --dry-run      print what would happen without making changes
  --help         show this help page
EOF
}

# Default to lightweight install when no options are provided. Done before
# any bash-4-only syntax (e.g. `declare -A`) so the common path works under
# /bin/bash 3.x and when this file is sourced from zsh.
if [[ $# -eq 0 ]]; then
  exec "$SCRIPT_DIR/light-install.sh" -a
fi

# --- Flag parsing ---
# Order here determines run order below.
FEATURES=(pacman yay terminal font printer logiops link services manual tmux gitconfig dconf xdg info)
declare -A SKIP
for k in "${FEATURES[@]}"; do SKIP[$k]=true; done
DRY_RUN=false

LONG="all,dry-run,help,$(IFS=,; printf '%s' "${FEATURES[*]}")"
OPTS="$(getopt -o '' --long "$LONG" --name "$(basename "$0")" -- "$@")" || { usage; exit 1; }
eval set -- "$OPTS"

while true; do
  case "$1" in
    --all)
      # 'terminal' is intentionally left skipped: pacman + yay together cover
      # all packages the --terminal flag would install.
      for k in "${FEATURES[@]}"; do
        if [[ "$k" != "terminal" ]]; then
          SKIP[$k]=false
        fi
      done
      shift
      ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help)    usage; exit 0 ;;
    --)        shift; break ;;
    --*)
      key="${1#--}"
      if [[ -z "${SKIP[$key]+x}" ]]; then
        warn "Unknown option: $1"
        usage
        exit 1
      fi
      SKIP[$key]=false
      shift
      ;;
    *) usage; exit 1 ;;
  esac
done

# Ensure dotfiles dir exists and switch to it (no subshell, so cwd persists).
[[ -d "$DOTFILES_ROOT" ]] || error "dotfiles must be at $DOTFILES_ROOT."
cd "$DOTFILES_ROOT"

# --- Helpers ---

# Detect whether a controlling terminal is actually usable (open succeeds).
# `[[ -r /dev/tty ]]` is unreliable: the file exists in non-interactive
# environments but fails to open with ENXIO.
if (: < /dev/tty) 2>/dev/null; then
  HAS_TTY=true
else
  HAS_TTY=false
fi

# Execute a command, or just announce it under --dry-run.
run() {
  if $DRY_RUN; then
    printf '\033[36m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# Like run, but routes stdin from the controlling terminal when one exists.
# Used for commands like `pacman` that may prompt for confirmation; falls
# back to inherited stdin in non-interactive contexts (CI, nested scripts).
run_tty() {
  if $HAS_TTY; then
    run "$@" < /dev/tty
  else
    run "$@"
  fi
}

# Prompt the user for a yes/no answer (reads from the controlling terminal so
# it works even when stdin is redirected).
confirm() {
  local reply
  read -p "$1 [Y/n] " -r reply < /dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Replace ^pattern$ with replace in file (with backup) after user confirmation.
# Fourth arg is an optional sudo-style prefix for the sed call.
confirmsed() {
  local file="$1" pattern="$2" replace="$3" user="${4:-}"

  if [[ ! -f "$file" ]]; then
    warn "$file does not exist."
    return
  fi

  if grep -Eq "^${pattern}\$" "$file"; then
    if $DRY_RUN; then
      info "[dry-run] would replace '$pattern' with '$replace' in $file"
      return
    fi
    if confirm "Edit $file to replace '$pattern' with '$replace'?"; then
      mkdir -pv "$(dirname "$BACKUPS_ROOT$file")"
      cp -nvi "$file" "$BACKUPS_ROOT$file" < /dev/tty
      $user sed -Ei "s@^${pattern}\$@${replace}@" "$file"
    fi
  elif ! grep -Eq "^${replace}\$" "$file"; then
    warn "Neither '$pattern' nor '$replace' were found in $file."
  fi
}

# Create a symlink at $target pointing to $src, backing up any existing file
# or stale symlink. Third arg is an optional sudo-style prefix.
make_symlink() {
  local src="$1" target="$2" sudo_cmd="${3:-}"

  if [[ ! -e "$src" ]]; then
    warn "Source does not exist, skipping: $src"
    return
  fi

  # Already pointing where we want — nothing to do.
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$src" ]]; then
    return
  fi

  run $sudo_cmd mkdir -pv "$(dirname "$target")"

  # Back up anything in the way (regular file OR symlink pointing elsewhere).
  if [[ -e "$target" || -L "$target" ]]; then
    run mkdir -pv "$(dirname "$BACKUPS_ROOT$target")"
    run_tty $sudo_cmd mv -vi "$target" "$BACKUPS_ROOT$target"
  fi

  run $sudo_cmd ln -snfv "$src" "$target"
}

# Return 0 if the given find path matches any entry in EXCLUDE_PATHS, either
# exactly or as a directory prefix.
should_exclude() {
  local path="$1" ex
  for ex in "${EXCLUDE_PATHS[@]}"; do
    [[ "$path" == "$ex" || "$path" == "$ex"/* ]] && return 0
  done
  return 1
}

# --- Package lists ---

# Pacman package list
TERMINAL_PACMAN=(
  "wmctrl"                                                      # CLI interface for X window manager
  "zsh"                                                         # zshell essentials
  "zsh-autosuggestions"                                         # .
  "zsh-syntax-highlighting"                                     # .
  "zsh-history-substring-search"                                # .
  "zsh-completions"                                             # .
  "tmux"                                                        # terminal multiplexer
  "git"                                                         # install.sh
  "make"                                                        # Lunarvim dependency
  "python"                                                      # Lunarvim dependency
  "npm"                                                         # Lunarvim dependency
  "cargo"                                                       # Lunarvim dependency
  "ripgrep"                                                     # Lunarvim telescope dependency
  "fd"                                                          # Lunarvim telescope dependency
  "neovim"                                                      # text editor
  "yarn"                                                        # markdown-preview dependency
  "noto-fonts"                                                  # special fonts
  "noto-fonts-cjk"                                              # .
  "noto-fonts-emoji"                                            # .
  "noto-fonts-extra"                                            # .
  "tree"                                                        # show directory contents in tree form
  "cmus"                                                        # Music player
  "locate"                                                      # locate files
  "xclip"                                                       # system clipboard tool
  "man"                                                         # manual
  "man-pages"                                                   # manual database
  "acpi"                                                        # battery status and acpi information
)

GNOME_PACMAN=(
  "gnome-shell"                                                 # gnome desktop environment
  "gnome-terminal"                                              # gnome default terminal
  "gdm"                                                         # gnome display manager
  "gnome-tweaks"                                                # more settings
  "gnome-control-center"                                        # settings
  "gparted"                                                     # disk partition editor
  "baobab"                                                      # disk usage analyzer
  "dconf-editor"                                                # gnome settings editor
  "seahorse"                                                    # keyring manager
  "papirus-icon-theme"                                          # nice app icon theme
  "nautilus"                                                    # gui file explorer
  "xdg-user-dirs-gtk"                                           # Manages "well-known" user directories (e.g. Documents, Videos, etc.)
  "okular"                                                      # PDF viewer
  "gnome-system-monitor"                                        # system monitor
  "fragments"                                                   # torrent downloader
  "gthumb"                                                      # image viewer
  "gnome-screenshot"                                            # screenshot tool
  "gst-plugin-pipewire"                                         # gnome screencast dependency
  "obs-studio"                                                  # Sophisticated recorder/streamer
  "xdg-desktop-portal"                                          # Enables pipewire to provide video capture (for obs)
  "xdg-desktop-portal-gnome"                                    # xdg-desktop-portal backend for gnome
  "totem"                                                       # video player (installs gst-plugins-good)
  "gst-libav"                                                   # required multimedia framework for totem
  "kid3"                                                        # audio metadata editor
  "bluez-utils"                                                 # bluetooth support
  "discord"                                                     # social media
  "solaar"                                                      # logitech pairing software
  "obsidian"                                                    # markdown note taker
)

LATEX_PACMAN=(
  "texlive-binextra"                                            # get latexmk
  "biber"                                                       # enable biber for latexmk
  "perl-clone"                                                  # fix missing dependency for biber (08-05-2022)
  "cpanminus"                                                   # install cpan modules more easily
)

# (hp) printer package list
PRINTER_PACMAN=(
  "cups"                                                        # standard printing system
  "system-config-printer"                                       # GUI printer configuration
  "hplip"                                                       # hp printer driver installer
)

GNOME_YAY=(
  "adw-gtk-theme"                                               # dark gtk theme
  "xcursor-breeze"                                              # cursor theme
  "insync"                                                      # drive sync
  "google-chrome"                                               # web browser
  "zoom"                                                        # video conferencing platform
)

# Exclude paths beginning with these prefixes when linking.
# Each entry is matched against `find` output exactly, or as a directory prefix.
EXCLUDE_PATHS=(
  "./.git"                          # dotfiles git repository information
  "./dump"                          # manually loaded configuration files
  "./.gitignore"
  "./install.sh"                    # this script!
  "./light-install.sh"              # a lighter version of this script!
  "./README.md"                     # dotfiles readme
  "./.backup"                       # temporary backup file of modified files
  "./Sessionx.vim"                  # vim Obsession session file
  "./.claude/settings.local.json"   # needs to be merged with user settings, rather than replacing it
  "./.claude/CLAUDE.md"             # needs to be merged with user CLAUDE.md, rather than replacing it
  "./tests"                         # dotfiles tests
  "./docs"                          # dotfile docs
)

# --- Section functions ---

# Install yay if it's not already on the system.
ensure_yay() {
  if command -v yay &>/dev/null; then
    return
  fi
  info "Installing yay..."
  run sudo pacman --needed -S git base-devel
  if $DRY_RUN; then
    info "[dry-run] would clone and build yay from AUR"
    return
  fi
  (
    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
  )
  rm -rf /tmp/yay
}

install_pacman() {
  info "Installing pacman packages for terminal..."
  run_tty sudo pacman --needed -Sq "${TERMINAL_PACMAN[@]}"
  info "Installing pacman packages for gnome..."
  run_tty sudo pacman --needed -Sq "${GNOME_PACMAN[@]}"
  info "Installing pacman packages for latex..."
  run_tty sudo pacman --needed -Sq "${LATEX_PACMAN[@]}"
}

install_yay() {
  ensure_yay
  info "Installing yay packages for terminal..."
  run_tty yay --answerclean None --answerdiff None --needed -Sq "${TERMINAL_YAY[@]}"
  info "Installing yay packages for gnome..."
  run_tty yay --answerclean None --answerdiff None --needed -Sq "${GNOME_YAY[@]}"
}

# Install only the terminal subset of packages. Skips work already covered by
# install_pacman / install_yay when those flags were also given.
install_terminal() {
  if ${SKIP[pacman]}; then
    info "Installing pacman packages for terminal..."
    run_tty sudo pacman --needed -Sq "${TERMINAL_PACMAN[@]}"
  fi
  if ${SKIP[yay]}; then
    ensure_yay
    info "Installing yay packages for terminal..."
    run_tty yay --answerclean None --answerdiff None --needed -Sq "${TERMINAL_YAY[@]}"
  fi

  curl -sS https://starship.rs/install.sh | sh
}

install_font() {
  if $DRY_RUN; then
    info "[dry-run] would install JetBrainsMono"
    return
  fi
  mkdir -p "$HOME/.local/share/fonts"
  (
    cd /tmp && rm -rf fonts && mkdir fonts && cd fonts
    curl -L -o "fonts.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" 
    unzip "fonts.zip"
    mv *.ttf "$HOME/.local/share/fonts"
  )
  rm -rf /tmp/fonts
}

install_printer() {
  info "Installing pacman packages for printer..."
  run_tty sudo pacman --needed -Sq "${PRINTER_PACMAN[@]}"
  run sudo systemctl enable --now cups
  info "Note: to install HP printer drivers, use 'hp-setup -i'."
}

install_logiops() {
  if ! systemctl list-unit-files | grep -q "logid.service"; then
    info "Installing PixlOne/logiops..."
    run sudo pacman --needed -S cmake libevdev libconfig pkgconf
    if $DRY_RUN; then
      info "[dry-run] would build and install PixlOne/logiops from source"
    else
      (
        cd /tmp && rm -rf logiops && git clone https://github.com/PixlOne/logiops && cd logiops
        mkdir -p build
        cd build
        cmake ..
        make
        sudo make install
      )
      rm -rf /tmp/logiops
    fi
  fi

  if [[ "$(systemctl is-active logid.service 2>/dev/null || true)" != "active" ]]; then
    info "Enabling logid.service..."
    run sudo systemctl enable --now logid.service
  fi
}

link_dotfiles() {
  local dotfile rel target user src
  while IFS= read -r -d '' dotfile; do
    if should_exclude "$dotfile"; then
      continue
    fi

    rel="${dotfile#./}"
    if [[ "$rel" == root/* ]]; then
      target="/${rel#root/}"
      user="sudo"
    else
      target="$HOME/$rel"
      user=""
    fi
    src="$DOTFILES_ROOT/$rel"
    make_symlink "$src" "$target" "$user"
  done < <(find . -type f -print0)
}

enable_services() {
  run systemctl enable --now auto-suspend.timer
}

apply_manual_patches() {
  confirmsed /etc/bluetooth/main.conf "#AutoEnable=false" "AutoEnable=true" sudo
}

install_tmux_plugins() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  if [[ ! -d "$tpm_dir" ]]; then
    info "Installing tpm..."
    run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    info "tpm installation complete."
  fi
}

configure_git() {
  if ! command -v git &>/dev/null; then
    warn "git command not found, skipping git config setup."
    return
  fi
  run git config --global push.autoSetupRemote true
  run git config --global core.excludesFile "$DOTFILES_ROOT/.config/git/ignore"
  run git config --global pull.rebase false
  run git config --global credential.helper true
}

load_dconf() {
  local dump_file="$DOTFILES_ROOT/dump/dconf/arch.dconf"

  info "Backing up current dconf configuration..."
  run mkdir -pv "$(dirname "$BACKUPS_ROOT$dump_file")"
  if $DRY_RUN; then
    info "[dry-run] would dump dconf to $BACKUPS_ROOT$dump_file"
    info "[dry-run] would load dconf from $dump_file"
    return
  fi

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  dconf dump / > "$tmp"
  cp -vi "$tmp" "$BACKUPS_ROOT$dump_file"

  dconf load / < "$dump_file"
  info "dconf configuration loaded."
}

configure_xdg() {
  info "Running xdg-user-dirs-update..."
  run xdg-user-dirs-update

  info "Setting default applications with xdg-mime..."
  run xdg-mime default okularApplication_pdf.desktop application/pdf
  run xdg-mime default org.gnome.gThumb.desktop      image/gif
  run xdg-mime default org.gnome.gThumb.desktop      image/jpeg
  run xdg-mime default org.gnome.gThumb.desktop      image/png
  run xdg-mime default org.gnome.gThumb.desktop      image/webp
  run xdg-mime default org.gnome.Totem.desktop       audio/mpeg
  run xdg-mime default org.gnome.Totem.desktop       audio/mp4
  run xdg-mime default nvim.desktop                  text/plain

  info "xdg update complete."
}

print_info() {
  cat <<EOF

Providing dump info...
'$DOTFILES_ROOT/dump' contains exported configuration files of various applications, typically those with guis.
dconf settings can be loaded automatically by using this installer with '--dconf'. Most settings need to be imported manually.

Configurations that must be loaded manually include:
 - Insync ignorerules: Account Settings > Ignore Rules (paste ignorerules text)
 - Okular shortcuts: Settings > Configure Keyboard Shortcuts > Manage Schemes > More Actions > Import Scheme (select default.shortcuts)
Files are available in $DOTFILES_ROOT/dump/<application>

EOF
}

# --- Main ---
info "Beginning dotfiles installation..."

${SKIP[pacman]}    || install_pacman
${SKIP[yay]}       || install_yay
${SKIP[terminal]}  || install_terminal
${SKIP[font]}      || install_font
${SKIP[printer]}   || install_printer
${SKIP[logiops]}   || install_logiops
${SKIP[link]}      || link_dotfiles
${SKIP[services]}  || enable_services
${SKIP[manual]}    || apply_manual_patches
${SKIP[tmux]}      || install_tmux_plugins
${SKIP[gitconfig]} || configure_git
${SKIP[dconf]}     || load_dconf
${SKIP[xdg]}       || configure_xdg
${SKIP[info]}      || print_info

info "dotfiles installation complete."
