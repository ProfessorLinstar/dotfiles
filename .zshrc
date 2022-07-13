# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

zstyle ':omz:update' mode reminder  # just remind me to update when it's time
zstyle ':omz:update' frequency 30

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=$ZSH/custom

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

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
alias vim=nvim
alias nvim=lvim
alias vis="source vis"
alias tt="gio trash"
alias la="ls -la"
