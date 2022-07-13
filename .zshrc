#
# ~/.zshrc
# 

# Use powerline
USE_POWERLINE="true"
# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi
# Use manjaro zsh prompt
if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
  source /usr/share/zsh/manjaro-zsh-prompt
fi

# Only show last three directories in filepath
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=...

# Prompt coloring
typeset -g POWERLEVEL9K_DIR_BACKGROUND=4
typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=4

################################################################################
# User changes
################################################################################

export LS_COLORS=$LS_COLORS:ow=0:ex=0 # Don't change color of directories/files with o+w permissions

# Aliases
alias py=python3.10
alias vi=lvim
alias nvim=lvim
alias vis="source vis"
alias tt="gio trash"
alias la="ls -la"
