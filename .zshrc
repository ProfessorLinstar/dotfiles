#
# ~/.zshrc
#

[[ ! -o login ]] && . "$HOME/.zprofile"                         # Source zprofile if shell was not interactive
typeset -U path                                                 # Remove duplicates in path/PATH

################################################################################
# Powershell and zsh plugins
################################################################################


# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Package list: zsh-theme-powerlevel10k
#               zsh-autosuggestions
#               zsh-syntax-highlighting
#               zsh-history-substring-search
#               zsh-completions

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

autoload -Uz compinit colors                                    # Autoload these zsh functions when called
compinit -d                                                     # Initialize zsh completion
colors                                                          # Activate color-coding for completion

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

################################################################################
# Shell config
################################################################################

# variables
HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000
WORDCHARS=${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters as words
ZLE_RPROMPT_INDENT=0                                            # No space after right prompt

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# Aliases
source ~/dotfiles/.config/sh/aliases.sh

# zsh config
source ~/dotfiles/.config/zsh/keybindings.zsh


################################################################################
# External packages
################################################################################

# opam configuration
[[ ! -r /home/linstar/.opam/opam-init/init.zsh ]] || source /home/linstar/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# Claude Code
# export ANTHROPIC_BEDROCK_BASE_URL=<base url here>
# export ANTHROPIC_AUTH_TOKEN=<auth token here>
export CLAUDE_CODE_USE_BEDROCK=1
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export DISABLE_TELEMETRY=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
