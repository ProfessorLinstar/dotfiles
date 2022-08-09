#!/bin/sh

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations.
# Location: ~/dotfiles/install.sh
################################################################################

usage() {
  echo "Usage: $0 [-a|-all] [-pgvylmtdixh]"
  echo "See README.md for more information."
}

SHORT=apgvylmtdixh
LONG=all,pacman,logiops,lunarvim,yay,link,manual,tmux,dconf,info,xdg,help
OPTS=$(getopt --options $SHORT --long $LONG --name $0 -- "$@")

SKIP_XDG=true
SKIP_DCONF=true
SKIP_DUMPINFO=true
SKIP_PACMAN=true
SKIP_YAY=true
SKIP_LOGIOPS=true
SKIP_LUNARVIM=true
SKIP_LINK=true
SKIP_MANUAL=true
SKIP_TMUX=true

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

eval set -- "$OPTS"
while true; do
  case "$1" in
    -a | --all )      SKIP_XDG=false;
                      SKIP_DCONF=false;
                      SKIP_DUMPINFO=false;
                      SKIP_PACMAN=false;
                      SKIP_YAY=false;
                      SKIP_LOGIOPS=false;
                      SKIP_LUNARVIM=false;
                      SKIP_LINK=false;
                      SKIP_MANUAL=false;
                      SKIP_TMUX=false;     shift; ;;

    -p | --pacman )   SKIP_PACMAN=false;   shift; ;;
    -g | --logiops )  SKIP_LOGIOPS=false;  shift; ;;
    -v | --lunarvim ) SKIP_LUNARVIM=false; shift; ;;
    -y | --yay )      SKIP_YAY=false;      shift; ;;
    -l | --link )     SKIP_LINK=false;     shift; ;;
    -m | --manual )   SKIP_MANUAL=false;   shift; ;;
    -t | --tmux )     SKIP_TMUX=false;     shift; ;;
    -d | --dconf )    SKIP_DCONF=false;    shift; ;;
    -i | --info )     SKIP_DUMPINFO=false; shift; ;;
    -x | --xdg )      SKIP_XDG=false;      shift; ;;

    -h | --help )     usage; exit 0;              ;;
    -- )              shift; break;               ;; # break on positional arguments
    * )               usage; exit 1;              ;;
  esac
done

# Directory setup
DOTFILES_ROOT="$HOME/dotfiles"                                  # dotfiles root directory
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"                           # backup dotfiles root directory
if ! ([[ -d "$DOTFILES_ROOT" ]] && cd "$DOTFILES_ROOT"); then   # Ensure that cwd is at ~/dotfiles
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
    mkdir -pv "$(dirname $BACKUPS_ROOT$file)" && cp -nvi "$file" "$BACKUPS_ROOT$file" < /dev/tty
    $user sed -Ei "s@^$pattern\$@$replace@" "$file"

  else
    grep -Eq "^$replace$" < "$file" || echo "Warning: Neither '$pattern' nor '$replace' were found in $file."
  fi
}


# Pacman package list
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
  "qgnomeplatform-qt5"                                          # gnome themes (adwaita) for qt5 applications
)

LATEX_PACMAN=(
  "texlive-most"                                                # provide most latex packages
  "texlive-bibtexextra"                                         # enable biblatex
  "biber"                                                       # enable biber for latexmk
  "perl-clone"                                                  # fix missing dependency for biber (08-05-2022)
  "cpanminus"                                                   # install cpan modules more easily
)

# Yay package list
TERMINAL_YAY=(
  "nerd-fonts-ubuntu-mono"                                      # nerd font
)

GNOME_YAY=(
  "adw-gtk-theme"                                               # dark gtk theme
  "xcursor-breeze"                                              # cursor theme
  "insync"                                                      # drive sync
  "google-chrome"                                               # web browser
)

# Exclude paths beginning with these prefixes when linking
EXCLUDE_PATHS=(
  "./.git"                                                      # git information
  "./dump"                                                      # manually loaded configuration files
  "./install.sh"                                                # this script!
  "./README.md"                                                 # dotfiles readme
  "./.backup"                                                   # temporary backup file of modified files
)

# Installation begins
echo "Beginning dotfiles installation..."

# Pacman packages
if ! $SKIP_PACMAN; then
  echo "Installing pacman packages for terminal..."; sudo pacman --needed -Sq ${TERMINAL_PACMAN[@]} < /dev/tty; echo
  echo "Installing pacman packages for gnome...";    sudo pacman --needed -Sq ${GNOME_PACMAN[@]}    < /dev/tty; echo
  echo "Installing pacman packages for latex...";    sudo pacman --needed -Sq ${LATEX_PACMAN[@]}    < /dev/tty; echo
fi

# Yay packages
if ! $SKIP_YAY; then
  if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    sudo pacman --needed -S git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd .. && rm -rf yay
  fi

  echo "Installing yay packages for terminal..."; yay --answerclean None --answerdiff None --needed -Sq ${TERMINAL_YAY[@]} < /dev/tty; echo
  echo "Installing yay packages for gnome...";    yay --answerclean None --answerdiff None --needed -Sq ${GNOME_YAY[@]}    < /dev/tty; echo
fi


# logiops
if ! $SKIP_LOGIOPS; then
  if ! systemctl list-unit-files | grep -q "logid.service"; then
    echo "Installing PixlOne/logiops..."
    sudo pacman --needed -S cmake libevdev libconfig pkgconf    # Logiops dependencies
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
fi



# Lunarvim
if ! $SKIP_LUNARVIM; then
  if [[ $(npm config get prefix) != "$HOME/.local" ]]; then
    echo "Resolving npm EACCES permissions..."
    npm config set prefix "$HOME/.local"                        # install global npm packages to local directory without sudo
  fi

  if ! command -v lvim &>/dev/null; then
    echo "Installing Lunarvim..."
    sudo pacman --needed -S git make python npm cargo           # Lunarvim dependencies
    gio trash -v ~/.config/lvim/config.lua                      # Prevent installation from overwriting existing config
    LV_BRANCH=rolling bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/rolling/utils/installer/install.sh)
  fi
fi


# dotfile links
if ! $SKIP_LINK; then
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
fi


# Manual modifications
if ! $SKIP_MANUAL; then
  confirmsed /etc/bluetooth/main.conf "#AutoEnable=false" "AutoEnable=true" sudo
  confirmsed ~/.local/share/lunarvim/site/pack/packer/opt/vimtex/autoload/vimtex/syntax/core.vim "  syntax iskeyword 48-57,a-z,A-Z,192-255" "  syntax iskeyword a-z,A-Z,192-255"
  confirmsed ~/.tmux/plugins/tmux-resurrect/strategies/nvim_session.sh '		echo "nvim -S"' '		echo "vis"'
  confirmsed ~/.tmux/plugins/tmux-resurrect/strategies/nvim_session.sh '		echo "nvim"' '		echo "vis"'
fi


# tmux plugins
if ! $SKIP_TMUX; then
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    echo "Installing tpm..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi
fi

# dconf settings
if ! $SKIP_DCONF; then
  DCONF_DUMP="$DOTFILES_ROOT/dump/dconf/arch.dconf"
  tmp="$(mktemp)"

  echo "Backing up current dconf configuration..."
  mkdir -pv "$(dirname $BACKUPS_ROOT$DCONF_DUMP)"
  dconf dump / > $tmp
  cp -vi $tmp "$BACKUPS_ROOT$DCONF_DUMP"
  rm $tmp

  dconf load / < $DCONF_DUMP
  echo "dconf configuration loaded."
fi

# xdg settings
if ! $SKIP_XDG; then
  echo "Running xdg-user-dirs-update..."
  xdg-user-dirs-update

  echo "Setting default applications with xdg-mime..."
  xdg-mime default okularApplication_pdf.desktop application/pdf
  xdg-mime default org.gnome.gThumb.desktop      image/gif
  xdg-mime default org.gnome.gThumb.desktop      image/jpeg
  xdg-mime default org.gnome.gThumb.desktop      image/png
  xdg-mime default org.gnome.gThumb.desktop      image/webp
  xdg-mime default org.gnome.Totem.desktop       audio/mpeg
  xdg-mime default org.gnome.Totem.desktop       audio/mp4
  xdg-mime default nvim.desktop                  text/plain

  echo "xdg update complete."
fi

# dump information
if ! $SKIP_DUMPINFO; then
  echo
  echo "Providing dump info..."
  echo "'$DOTFILES_ROOT/dump' contains exported configuration files of various applications, typically those with gui's."
  echo "dconf settings can be loaded automatically by using this installer with '--load-dconf'. Most settings need to be imported"
  echo "manually."
  echo
  echo "Configurations that must be loaded manually include:"
  echo " - Insync ignorerules: Account Settings > Ignore Rules (paste ignorerules text)"
  echo " - Okular shortcuts: Settings > Configure Keyboard Shortcuts > Manage Schemes > More Actions > Import Scheme (select default.shortcuts)"
  echo "Files are available in $DOTFILES_ROOT/dump/<application>"
  echo
fi

echo "dotfiles installation complete."
