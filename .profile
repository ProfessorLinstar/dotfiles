#
# ~/.profile
#

# if running zshell
[[ -n "$ZSH_VERSION" ]] && [[ -f "$HOME/.zshrc" ]] && . "$HOME/.zshrc"

# if running bash
[[ -n "$BASH_VERSION" ]] && [[ -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
