#!/bin/sh

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

DOTFILES_ROOT="$HOME/dotfiles"
if ! ([[ -d "$DOTFILES_ROOT" ]] && cd "$DOTFILES_ROOT"); then
  echo "dotfiles must be at $DOTFILES_ROOT."
  exit 1
fi

function confirmrm {
  read -p "rm "$1"? [Y/n] " -r
  [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

TERMINAL_PACMAN=(
  "zsh"
  "zsh-theme-powerlevel10k"
  "zsh-autosuggestions"
  "zsh-syntax-highlighting"
  "zsh-history-substring-search"
  "zsh-completions"
  "tmux"
  "git"
  "make"
  "python"
  "npm"
  "cargo"
  "neovim"
  "noto-fonts"
  "noto-fonts-cjk"
  "noto-fonts-emoji"
  "noto-fonts-extra"
  "tree"
  "cmus"
  "locate"
  "networkmanager"
  "xclip"
)

GNOME_PACMAN=(
  "gnome-shell"
  "gdm"
  "gnome-terminal"
  "gnome-tweaks"
  "gnome-control-center"
  "gparted"
  "dconf-editor"
  "papirus-icon-theme"
  "nautilus"
  "gnome-screenshot"
  "okular"
  "gnome-system-monitor"
  "fragments"
  "gthumb"
  "kid3"
  "bluez"
  "bluez-utils"
)

TERMINAL_YAY=(
  "nerd-fonts-ubuntu-mono"
)

GNOME_YAY=(
  "adw-gtk-theme"
  "xcursor-breeze"
  "insync"
  "google-chrome"
)

EXCLUDE_PATHS=(
  "./.git"
  "./dump"
  "./install.sh"
  "./README.md"
)

# Packages
echo "Installing pacman packages for terminal..."
sudo pacman --needed -Sq ${TERMINAL_PACMAN[@]} < /dev/tty
echo "Installing pacman packages for gnome..."
sudo pacman --needed -Sq ${GNOME_PACMAN[@]} < /dev/tty

if ! command -v yay &>/dev/null; then
  echo "Installing yay..."
  sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd .. && rm -rf yay
fi

echo "Installing yay packages for terminal..."
yay --needed -Sq ${TERMINAL_YAY[@]} < /dev/tty
echo "Installing yay packages for gnome..."
yay --needed -Sq ${GNOME_YAY[@]} < /dev/tty


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
  [[ -f $target ]] && [[ ! -L $target ]] && confirmrm $target < /dev/tty && $user rm -v $target
  [[ -L $target ]] || $user ln -sv $(sed "s@^\.\(.*\)@"$(pwd)"\1@" <<< $dotfile) $target

done <<< $(find . -type f -print | grep -Ev $(tr " " "|" <<< ${EXCLUDE_PATHS[@]}) )


# tmux plugins
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "Installing tpm..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

echo "Installation and linking complete."
