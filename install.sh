#!/bin/sh

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

function confirmrm {
  read -p "rm "$1"? [Y/n] " -r
  [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

PACMAN_PACKAGES=(
  "zsh"
  "zsh-theme-powerlevel10k"
  "zsh-autosuggestions"
  "zsh-syntax-highlighting"
  "zsh-history-substring-search"
  "zsh-completions"
  "neovim"
  "tmux"
  "git"
  "make"
  "python"
  "npm"
  "cargo"
)

EXCLUDE_PATHS=(
  "./.git"
  "./dump"
  "./install.sh"
  "./README.md"
)

echo "Installing packages..."
for package in ${PACMAN_PACKAGES[@]}; do
  sudo pacman --needed -Sq $package < /dev/tty
done

echo "Linking dotfiles..."
while read dotfile; do

  if [[ -n $(grep -E "./root" <<< $dotfile) ]]; then
    target=$(sed "s@\./root\(.*\)@\1@" <<< $dotfile)
    user="sudo"
  else
    target=$(sed "s@\.\(.*\)@$HOME\1@" <<< $dotfile)
    user=""
  fi

  [[ -d $(dirname $target) ]] || $user mkdir -pv $(dirname $target)
  [[ -f $target ]] && [[ ! -L $target ]] && confirmrm $target < /dev/tty && $user rm -v $target
  [[ -L $target ]] || $user ln -sv $(sed "s@\.\(.*\)@"$(pwd)"\1@" <<< $dotfile) $target

done <<< $(find . -type f -print | grep -Ev $(tr " " "|" <<< ${EXCLUDE_PATHS[@]}) )

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "Installing tpm..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

if [[ $(npm config get prefix) != "$HOME/.local" ]]; then
  echo "Resolving npm EACCES permissions..."
  npm config set prefix "$HOME/.local"
fi

if ! command -v lvim &>/dev/null; then
  echo "Installing Lunarvim..."
  LV_BRANCH=rolling bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/rolling/utils/installer/install.sh)
fi

if ! command -v yay &>/dev/null; then
  echo "Installing yay..."
  sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd .. && rm -rf yay
fi

echo "Installation and linking complete."
