#
# ~/.zshrc
#

[[ ! -o login ]] && . "$HOME/.zprofile"                         # Source zprofile if shell was not interactive
typeset -U path                                                 # Remove duplicates in path/PATH

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
# Variables and Aliases
################################################################################

# variables
HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000
WORDCHARS=${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters part of the word

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# defaults
alias ls="ls --color=auto"                                      #
alias la="ls -la"                                               # list all with filesizes in MB
alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

# shortcuts
alias py=python3.10                                             # Python shortcut
alias vi=lvim                                                   #
alias vis="source vis"                                          # Allow vis to change cwd
alias gitu='git add -u && git commit && git push'               #
alias tt="gio trash"                                            # move file to trash

################################################################################
# zsh Options And Key Bindings
################################################################################

## Keybindings
bindkey -e                                                      # EMACS emulation default keymap
bindkey '^[[A' history-substring-search-up                      # Up key
bindkey '^[[B' history-substring-search-down                    # Down key
bindkey '^[[3~' delete-char                                     # Delete key
bindkey '^[[Z' undo                                             # Shift+tab undo last action

## Options section
setopt correct                                                  # Auto correct mistakes
setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
setopt nocaseglob                                               # Case insensitive globbing
setopt rcexpandparam                                            # Array expension with parameters
setopt nocheckjobs                                              # Don't warn about running processes when exiting
setopt numericglobsort                                          # Sort filenames numerically when it makes sense
setopt nobeep                                                   # No beep
setopt appendhistory                                            # Immediately append history instead of overwriting
setopt histignorealldups                                        # If a new command is a duplicate, remove the older one
setopt inc_append_history                                       # save commands are added to the history immediately, otherwise only when shell exits.
setopt histignorespace                                          # Don't save commands that start with space

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                              # automatically find new executables in path

# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache
