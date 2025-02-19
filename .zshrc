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

# defaults
alias ls="ls --color=auto"                                      #
alias la="ls -la"                                               # list all with filesizes in MB
alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

# shortcuts
alias py=python3.10                                             # Python shortcut
alias activate=". venv/bin/activate"                            # Python virtual environment activation shortcut
alias vi=lvim                                                   #
alias vis="source vis"                                          # Allow vis to change cwd
alias gitu='git pull && git add -u && git commit && git push'   #
alias tt="gio trash"                                            # move file to trash

# git shortcuts
alias gs="git status"
alias gd="git diff"
alias gds="git diff --staged"
alias gr="git restore --staged"
alias gc="git checkout"
alias ga="git add"
alias gm="git commit -m"
alias gam="ga -u && gm"
alias ghp="git stash push -u"
alias ghl="git stash list"
alias gp="git push"
gmp() { gm "$1" && git push }
gamp() { gam "$1" && git push }
gb() {
  rebase="$1"
  remote="$(git remote show)"

  command gh >/dev/null && target="$(gh pr view --json baseRefName -q '.baseRefName')"
  if [ -z "$target" ]; then
    echo "Could not use 'gh' to determine target branch."
  fi

  if [ -n "$rebase" ]; then
    echo "Using provided branch '$rebase' as rebase target."
  elif [ -n "$target" ]; then
    rebase="$target"
    echo "Using remote PR target branch '$rebase' as rebase target."
  else
    rebase="$(git rev-parse --abbrev-ref "$remote"/HEAD | sed "s@$remote/@@")"
    echo "Using remote HEAD '$rebase' as rebase target."
  fi

  if [ "$rebase" != "$target" ]; then
    echo "Warning: Remote target branch ('$target') is not the same as provided rebase branch ('$rebase')."
  fi

  if [ -z "$rebase" ]; then
    echo "Rebase branch could not be found."
    return 1
  fi

  cmd="git fetch && git fetch . "$remote/$rebase:$rebase" && git rebase -i "$rebase""
  echo "Command to run: $cmd"
  read -n 1
  echo "Running command..."
  eval "$cmd"
}

################################################################################
# zsh Options And Key Bindings
################################################################################

## Keybindings
bindkey -e                                                      # EMACS emulation default keymap
bindkey '^[[A' history-substring-search-up                      # Up key
bindkey '^[[B' history-substring-search-down                    # Down key
bindkey '^[[3~' delete-char                                     # Delete key
bindkey '^[u' undo                                              # Alt+u to undo last action
bindkey '^[r' redo                                              # Alt+r to redo last action

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

# opam configuration
[[ ! -r /home/linstar/.opam/opam-init/init.zsh ]] || source /home/linstar/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null
