#
# ~/.bashrc
#

! (shopt -q login_shell) && . "$HOME/.bash_profile"             # Source profile if not a login shell
[[ $- != *i* ]] && return                                       # Leave if shell is not interactive (for safety)

################################################################################
# Variables and Aliases
################################################################################

export PROMPT_DIRTRIM=3 # Only show last three directories in filepath
