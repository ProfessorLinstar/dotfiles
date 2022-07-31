#!/bin/sh
 
################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates 
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

function confirmrm {
  read -p "rm "$1"? [Y/n] " -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

PACMAN_PACKAGES=(
  "zsh"
  "zsh-theme-powerlevel10k"
  "zsh-autosuggestions"
  "zsh-syntax-highlighting"
  "zsh-history-substring-search"
  "zsh-completions"
  "neovim"
)

EXCLUDE_PATHS=(
  "./.git"
  "./dump"
  "./install.sh"
  "./README.md"
)

echo "Installing packages..."
for package in ${PACMAN_PACKAGES[@]}; do
  sudo pacman --needed -S $package < /dev/tty
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

echo "Installation and linking complete."
