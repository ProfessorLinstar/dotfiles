#
# ~/.bashrc
#

! (shopt -q login_shell) && . "$HOME/.bash_profile"             # Source profile if not a login shell
[[ $- != *i* ]] && return                                       # Leave if shell is not interactive (for safety)

################################################################################
# Variables and Aliases
################################################################################

export PROMPT_DIRTRIM=3 # Only show last three directories in filepath

# defaults
alias ls="ls --color=auto"                                      #
alias la="ls -la --block-size=M"                                # list all with filesizes in MB
alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

# shortcuts
alias py=python3.10                                             # Python shortcut
alias vi=lvim                                                   #
alias vim=\\nvim                                                # Make neovim the default
alias nvim=lvim                                                 # Make tmux use Lunarvim when restoring
alias vis="source vis"                                          # Allow vis to change cwd
alias gitu='git add -u && git commit && git push'               #
alias tt="gio trash"                                            # move file to trash
