#!/bin/sh

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

# Ensure that cwd is at ~/dotfiles
DOTFILES_ROOT="$HOME/dotfiles"
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
    local backup="$DOTFILES_ROOT/.backup$file"
    mkdir -pv "$(dirname $backup)" && cp -v "$file" "$backup"
    $user sed -Ei "s@^$pattern\$@$replace@" "$file"

  else
    grep -Eq "^$replace$" < "$file" || echo "Warning: Neither '$pattern' nor '$replace' were found in $file."
  fi
}


TERMINAL_PACMAN=(
  "zsh"                                                         #
  "zsh-theme-powerlevel10k"                                     #
  "zsh-autosuggestions"                                         #
  "zsh-syntax-highlighting"                                     #
  "zsh-history-substring-search"                                #
  "zsh-completions"                                             #
  "tmux"                                                        #
  "git"                                                         #
  "make"                                                        #
  "python"                                                      #
  "npm"                                                         #
  "cargo"                                                       #
  "neovim"                                                      #
  "noto-fonts"                                                  #
  "noto-fonts-cjk"                                              #
  "noto-fonts-emoji"                                            #
  "noto-fonts-extra"                                            #
  "tree"                                                        #
  "cmus"                                                        #
  "locate"                                                      #
  "networkmanager"                                              #
  "xclip"                                                       #
  "man"                                                         #
  "man-pages"                                                   #
)

GNOME_PACMAN=(
  "gnome-shell"                                                 #
  "gdm"                                                         #
  "gnome-terminal"                                              #
  "gnome-tweaks"                                                #
  "gnome-control-center"                                        #
  "gparted"                                                     #
  "dconf-editor"                                                #
  "papirus-icon-theme"                                          #
  "nautilus"                                                    #
  "gnome-screenshot"                                            #
  "okular"                                                      # PDF viewer
  "gnome-system-monitor"                                        # System monitor
  "fragments"                                                   # Torrent downloader
  "gthumb"                                                      # Image viewer
  "totem"                                                       # Video player
  "gst-libav"                                                   # Required multimedia framework for totem
  "kid3"                                                        # audio metadata editor
  "bluez-utils"                                                 # Bluetooth support
  "discord"                                                     # Social media
  "qgnomeplatform-qt5"                                          # Gnome themes (adwaita) for qt5 applications
)

LATEX_PACMAN=(
  "texlive-most"                                                # Provide most latex packages
  "texlive-bibtexextra"                                         # Enable biblatex
  "biber"                                                       # Enable biber for latexmk
  "perl-clone"                                                  # Fix missing dependency for biber (08-05-2022)
  "cpanminus"                                                   # install cpan modules more easily
)

TERMINAL_YAY=(
  "nerd-fonts-ubuntu-mono"                                      #
)

GNOME_YAY=(
  "adw-gtk-theme"                                               #
  "xcursor-breeze"                                              #
  "insync"                                                      #
  "google-chrome"                                               #
)

# Exclude paths beginning with these prefixes when linking
EXCLUDE_PATHS=(
  "./.git"                                                      #
  "./dump"                                                      #
  "./install.sh"                                                #
  "./README.md"                                                 #
  "./.backup"                                                   #
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
  [[ -f $target ]] && [[ ! -L $target ]] && $user rm -vi $target
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
