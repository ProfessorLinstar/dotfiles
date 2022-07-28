#
# ~/.bash_profile
#

[[ -f "$HOME/.profile" ]] && . "$HOME/.profile"
[[ $- == *i* ]] && shopt -q login_shell && . "$HOME/.bashrc"
