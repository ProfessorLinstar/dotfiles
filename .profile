#
# ~/.profile
#

[[ -n "$ZSH_VERSION" ]]  && [[ -f "$HOME/.zshrc" ]]  && . "$HOME/.zshrc"
[[ -n "$BASH_VERSION" ]] && [[ -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"

################################################################################
# Environmental Variables
################################################################################

export PATH="$HOME/bin${PATH:+:$PATH}"
export PATH="$HOME/.local/bin${PATH:+:$PATH}"

export PYTHONPATH="~/.local/lib/python3.10/site-packages${PYTHONPATH:+:$PYTHONPATH}"

export LS_COLORS=$LS_COLORS:ow=0:ex=0 # Don't change color of directories/files with o+w permissions
