#!/bin/bash
# Claude Code statusLine script.
# Reads JSON from stdin and prints a formatted status line:
#   <cwd> <git-branch> <context-window-%>

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir' | xargs basename)
branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git --no-optional-locks rev-parse --short HEAD 2>/dev/null \
  || echo '')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_int=$([ -n "$used" ] && printf '%.0f' "$used" || echo '')

blue='\033[34m'
green='\033[32m'
dim='\033[2m'
reset='\033[0m'

git_info=$([ -n "$branch" ] && printf '  %b%s%b' "$green" "$branch" "$reset" || echo '')
ctx_info=$([ -n "$used_int" ] && printf ' %b%s%%%b' "$dim" "$used_int" "$reset" || echo '')

printf '%b%s%b%s%s' "$blue" "$cwd" "$reset" "$git_info" "$ctx_info"
