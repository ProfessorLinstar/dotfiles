#!/bin/bash
# Claude Code statusLine script.
# Reads JSON from stdin and prints a formatted status line:
#   <cwd> <git-branch> [PR-url] <context-window-%>

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir' | xargs basename)
full_cwd=$(echo "$input" | jq -r '.workspace.current_dir')
branch=$(cd "$full_cwd" 2>/dev/null && git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git --no-optional-locks rev-parse --short HEAD 2>/dev/null \
  || echo '')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_int=$([ -n "$used" ] && printf '%.0f' "$used" || echo '')

# PR URL: read from per-repo cache, lazy-lookup on first render per repo
PR_CACHE_DIR="/tmp/claude-pr-cache"
repo_key=$(echo -n "$full_cwd" | md5sum | cut -d' ' -f1)
cache_file="${PR_CACHE_DIR}/${repo_key}"
checked_file="${PR_CACHE_DIR}/${repo_key}.checked"

pr_url=""
if [ -f "$cache_file" ]; then
  pr_url=$(cat "$cache_file")
elif [ ! -f "$checked_file" ] && [ -n "$branch" ]; then
  mkdir -p "$PR_CACHE_DIR"
  touch "$checked_file"
  pr_url=$(cd "$full_cwd" && gh pr view --json url -q .url 2>/dev/null || true)
  if [ -n "$pr_url" ]; then
    echo "$pr_url" > "$cache_file"
  fi
fi

blue='\033[34m'
green='\033[32m'
purple='\033[35m'
dim='\033[2m'
reset='\033[0m'

git_info=$([ -n "$branch" ] && printf '  %b%s%b' "$green" "$branch" "$reset" || echo '')
pr_info=$([ -n "$pr_url" ] && printf ' %b%s%b' "$purple" "$pr_url" "$reset" || echo '')
ctx_info=$([ -n "$used_int" ] && printf ' %b%s%%%b' "$dim" "$used_int" "$reset" || echo '')

printf '%b%s%b%s%s%s' "$blue" "$cwd" "$reset" "$git_info" "$pr_info" "$ctx_info"
