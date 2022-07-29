#
# ~/.profile
#

# Environmental Variables
export PATH="$HOME/.local/bin${PATH:+:$PATH}"
export PYTHONPATH="~/.local/lib/python3.10/site-packages${PYTHONPATH:+:$PYTHONPATH}"
export LS_COLORS=$LS_COLORS:ow=0:ex=0 # Don't change color of directories/files with o+w permissions
export EDITOR=/usr/bin/neovim
