#
# ~/.profile
#

# Environmental Variables
export PATH="$HOME/.local/bin${PATH:+:$PATH}"                   # Path to user executables
export LS_COLORS=$LS_COLORS:ow=0:ex=0                           # Don't change color of directories/files with o+w permissions
export EDITOR=/usr/bin/neovim                                   # Change default editor
export QT_QPA_PLATFORMTHEME=gnome                               # Make QT applications use gnome theme when launched from terminal
