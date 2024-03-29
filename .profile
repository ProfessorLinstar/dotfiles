#
# ~/.profile
#

# Environmental Variables
export PATH="$HOME/.local/bin${PATH:+:$PATH}"                   # User executables
export PATH="$HOME/go/bin${PATH:+:$PATH}"                       # Go executables
export PATH="/usr/bin/vendor_perl${PATH:+:$PATH}"               # Perl executables (e.g. biber)
export PYTHONPATH="$HOME/.local/lib/python3.10/site-packages${PYTHONPATH:+:$PYTHONPATH}"  # Path to user Python modules

export LS_COLORS=$LS_COLORS:ow=0:ex=0                           # Don't change color of directories/files with o+w permissions
export EDITOR=/usr/bin/neovim                                   # Change default editor
export QT_QPA_PLATFORMTHEME=gnome                               # Make QT applications use gnome theme when launched from terminal
