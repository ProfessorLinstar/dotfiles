#!/bin/sh

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

# Ensure that cwd is at ~/dotfiles
DOTFILES_ROOT="$HOME/dotfiles"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
if ! ([[ -d "$DOTFILES_ROOT" ]] && cd "$DOTFILES_ROOT"); then
  echo "dotfiles must be at $DOTFILES_ROOT."
  exit 1
fi

# Get user confirmation.
function confirm {
  read -p "$1 [Y/n] " -r
  [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

# Tries to $pattern in $replace in $file if it exists, and backs up original in ./.backup.
function confirmsed {
  local file="$1"; local pattern="$2"; local replace="$3"; local user="$4"

  if [[ ! -f "$file" ]]; then
    echo "Warning: $file does not exist." 

  elif grep -Eq "^$pattern$" < "$file" && confirm "Edit $file to replace '$pattern' with '$replace'?"; then
    local backup="$BACKUPS_ROOT$file"
    mkdir -pv "$(dirname $backup)" && cp -nvi "$file" "$backup" < /dev/tty
    $user sed -Ei "s@^$pattern\$@$replace@" "$file"

  else
    grep -Eq "^$replace$" < "$file" || echo "Warning: Neither '$pattern' nor '$replace' were found in $file."
  fi
}


TERMINAL_PACMAN=(
  "zsh"                                                         # zshell essentials
  "zsh-theme-powerlevel10k"                                     # .
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
  "noto-fonts"                                                  # special fonts
  "noto-fonts-cjk"                                              # .
  "noto-fonts-emoji"                                            # .
  "noto-fonts-extra"                                            # .
  "tree"                                                        # show directory contents in tree form
  "cmus"                                                        # Music player
  "locate"                                                      # locate files
  "networkmanager"                                              # ensure internet is available
  "xclip"                                                       # system clipboard tool
  "man"                                                         # manual
  "man-pages"                                                   # manual database
)

GNOME_PACMAN=(
  "gnome-shell"                                                 # gnome desktop environment
  "gdm"                                                         # gnome display manager
  "gnome-terminal"                                              # terminal for gnome
  "gnome-tweaks"                                                # more settings
  "gnome-control-center"                                        # settings
  "gparted"                                                     # disk partition editor
  "dconf-editor"                                                # gnome settings editor
  "papirus-icon-theme"                                          # nice app icon theme
  "nautilus"                                                    # gui file explorer
  "gnome-screenshot"                                            # screenshot tool
  "okular"                                                      # PDF viewer
  "gnome-system-monitor"                                        # system monitor
  "fragments"                                                   # torrent downloader
  "gthumb"                                                      # image viewer
  "totem"                                                       # video player
  "gst-libav"                                                   # required multimedia framework for totem
  "kid3"                                                        # audio metadata editor
  "bluez-utils"                                                 # bluetooth support
  "discord"                                                     # social media
  "qgnomeplatform-qt5"                                          # gnome themes (adwaita) for qt5 applications
)

LATEX_PACMAN=(
  "texlive-most"                                                # provide most latex packages
  "texlive-bibtexextra"                                         # enable biblatex
  "biber"                                                       # enable biber for latexmk
  "perl-clone"                                                  # fix missing dependency for biber (08-05-2022)
  "cpanminus"                                                   # install cpan modules more easily
)

TERMINAL_YAY=(
  "nerd-fonts-ubuntu-mono"                                      # nerd font
)

GNOME_YAY=(
  "adw-gtk-theme"                                               # dark gtk theme
  "xcursor-breeze"                                              # cursor theme
  "insync"                                                      # drive sync
  "google-chrome"                                               #
)

# Exclude paths beginning with these prefixes when linking
EXCLUDE_PATHS=(
  "./.git"                                                      # git information
  "./dump"                                                      # manually loaded configuration files
  "./install.sh"                                                # this script!
  "./README.md"                                                 # dotfiles readme
  "./.backup"                                                   # temporary backup file of modified files
)

# Packages
echo "Installing pacman packages for terminal..."
sudo pacman --needed -Sq ${TERMINAL_PACMAN[@]} < /dev/tty
echo "Installing pacman packages for gnome..."
sudo pacman --needed -Sq ${GNOME_PACMAN[@]} < /dev/tty
echo "Installing pacman packages for latex..."
sudo pacman --needed -Sq ${LATEX_PACMAN[@]} < /dev/tty

if ! command -v yay &>/dev/null; then
  echo "Installing yay..."
  sudo pacman --needed -S git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd .. && rm -rf yay
fi

echo "Installing yay packages for terminal..."
yay --answerclean None --answerdiff None --needed -Sq ${TERMINAL_YAY[@]} < /dev/tty
echo "Installing yay packages for gnome..."
yay --answerclean None --answerdiff None --needed -Sq ${GNOME_YAY[@]} < /dev/tty


# logiops
if ! systemctl list-unit-files | grep -q "logid.service"; then
  echo "Installing PixlOne/logiops..."
  sudo pacman --needed -S cmake libevdev libconfig pkgconf
  git clone https://github.com/PixlOne/logiops
  cd logiops

  mkdir build
  cd build
  cmake ..
  make
  sudo make install

  cd ../..
  rm -rf logiops
fi

if [[ $(systemctl is-active logid.service) != "active" ]]; then
  echo "Enabling logid.service..."
  sudo systemctl enable --now logid.service
fi


# Lunarvim
if [[ $(npm config get prefix) != "$HOME/.local" ]]; then
  echo "Resolving npm EACCES permissions..."
  npm config set prefix "$HOME/.local"
fi

if ! command -v lvim &>/dev/null; then
  echo "Installing Lunarvim..."
  gio trash -v ~/.config/lvim/config.lua # Prevent installation from overwriting existing config
  LV_BRANCH=rolling bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/rolling/utils/installer/install.sh)
fi


# dotfile links
echo "Linking dotfiles..."
while read dotfile; do

  if [[ -n $(grep -E "^\./root" <<< $dotfile) ]]; then
    target=$(sed "s@^\./root\(.*\)@\1@" <<< $dotfile)
    user="sudo"
  else
    target=$(sed "s@^\.\(.*\)@$HOME\1@" <<< $dotfile)
    user=""
  fi

  [[ -d $(dirname $target) ]] || $user mkdir -pv $(dirname $target)
  [[ -f $target ]] && [[ ! -L $target ]] && $user mv -vi $target "$BACKUPS_ROOT$target" < /dev/tty
  [[ -L $target ]] || $user ln -sv $(sed "s@^\.\(.*\)@"$(pwd)"\1@" <<< $dotfile) $target

done <<< $(find . -type f -print | grep -Ev $(tr " " "|" <<< ${EXCLUDE_PATHS[@]}) )


# Manual modifications
confirmsed /etc/bluetooth/main.conf "#AutoEnable=false" "AutoEnable=true" sudo
confirmsed ~/.local/share/lunarvim/site/pack/packer/opt/vimtex/autoload/vimtex/syntax/core.vim "  syntax iskeyword 48-57,a-z,A-Z,192-255" "  syntax iskeyword a-z,A-Z,192-255"
confirmsed ~/.tmux/plugins/tmux-resurrect/strategies/nvim_session.sh '		echo "nvim -S"' '		echo "vis"'
confirmsed ~/.tmux/plugins/tmux-resurrect/strategies/nvim_session.sh '		echo "nvim"' '		echo "vis"'


# tmux plugins
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "Installing tpm..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

echo "Installation and linking complete."
