#
# ~/.bashrc
#

! (shopt -q login_shell) && . "$HOME/.bash_profile"

[[ $- != *i* ]] && return

################################################################################
# Variables and Aliases
################################################################################

export PROMPT_DIRTRIM=3 # Only show last three directories in filepath

# defaults
alias ls="ls --color=auto"
alias la="ls -la --block-size=M"
alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

# shortcuts
alias py=python3.10
alias vi=lvim
alias vim=\\nvim
alias nvim=lvim
alias vis="source vis"
alias gitu='git add -u && git commit && git push'
alias tt="gio trash"
