#!/bin/bash
# Claude Code statusLine script.
# Renders the per-session list of PRs Claude is tracking, with the
# currently-checked-out (repo, branch) highlighted. Falls back to a
# single-line cwd/branch/pr view when no session state exists.
#
# Also maintains /tmp/claude-pr-state/_by_workspace/<md5(workspace)> as
# a pointer to the active session_key so /refresh-pr-state and other
# slash commands can find this session's state file.

input=$(cat)

full_cwd=$(echo "$input" | jq -r '.workspace.current_dir')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_int=$([ -n "$used" ] && printf '%.0f' "$used" || echo '')
transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')

# Canonical repo root + current branch for the current cwd
cur_repo=$(git -C "$full_cwd" rev-parse --show-toplevel 2>/dev/null)
[ -z "$cur_repo" ] && cur_repo="$full_cwd"
cur_branch=$(git -C "$full_cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$full_cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null \
  || echo '')

shorten() {
  local p="$1"
  if [ -n "$HOME" ] && [[ "$p" == "$HOME"* ]]; then
    printf '~%s' "${p#$HOME}"
  else
    printf '%s' "$p"
  fi
}

blue='\033[34m'
green='\033[32m'
purple='\033[35m'
dim='\033[2m'
bold='\033[1m'
reset='\033[0m'

session_key=""
state_file=""
if [ -n "$transcript" ]; then
  session_key=$(echo -n "$transcript" | md5sum | cut -d' ' -f1)
  state_file="/tmp/claude-pr-state/$session_key"
  # Workspace -> session pointer (lets slash commands find this state file)
  if [ -n "$full_cwd" ]; then
    mkdir -p /tmp/claude-pr-state/_by_workspace 2>/dev/null
    ws_key=$(echo -n "$full_cwd" | md5sum | cut -d' ' -f1)
    echo "$session_key" > "/tmp/claude-pr-state/_by_workspace/$ws_key" 2>/dev/null
  fi
fi

if [ -n "$state_file" ] && [ -s "$state_file" ]; then
  # Sort tracked rows by (repo asc, stack depth asc). Depth is the number
  # of base-branch hops back to a row not in the session set.
  sorted=$(awk -F'\t' '
    { lines[NR]=$0; repo[NR]=$1; br[NR]=$2; base[NR]=$4 }
    END {
      n = NR
      for (i = 1; i <= n; i++) {
        cur = i; d = 0; seen = "|"
        while (1) {
          parent = 0
          for (j = 1; j <= n; j++) {
            if (j != cur && repo[j] == repo[cur] && br[j] == base[cur]) { parent = j; break }
          }
          if (parent == 0) break
          if (index(seen, "|" parent "|") > 0) break
          seen = seen parent "|"
          cur = parent; d++
          if (d > n) break
        }
        depth[i] = d
        order[i] = i
      }
      for (i = 2; i <= n; i++) {
        j = i
        while (j > 1) {
          a = order[j-1]; b = order[j]
          if (repo[a] > repo[b]) { order[j-1]=b; order[j]=a; j--; continue }
          if (repo[a] == repo[b] && depth[a] > depth[b]) { order[j-1]=b; order[j]=a; j--; continue }
          break
        }
      }
      for (i = 1; i <= n; i++) print lines[order[i]]
    }
  ' "$state_file")

  out=""
  shown_current=0
  while IFS=$'\t' read -r r br_ pr_ base_ num_ ts_; do
    [ -z "$r" ] && continue
    short_r=$(shorten "$r")
    if [ "$r" = "$cur_repo" ] && [ "$br_" = "$cur_branch" ]; then
      shown_current=1
      line=$(printf '%b▶ %s%b  %b%s%b  %b%s%b' \
        "$bold$blue" "$short_r" "$reset" \
        "$green" "$br_" "$reset" \
        "$purple" "$pr_" "$reset")
    else
      line=$(printf '%b  %s  %s  %s%b' "$dim" "$short_r" "$br_" "$pr_" "$reset")
    fi
    out="${out}${line}"$'\n'
  done <<< "$sorted"

  # If the current (repo, branch) isn't part of the tracked stack, render
  # it as a separate block below with a blank-line separator. The current
  # branch may be unrelated to what the session is tracking — don't mix it
  # into the stack.
  if [ "$shown_current" -eq 0 ] && [ -n "$cur_repo" ]; then
    # Try to find a PR URL for the current branch via the per-repo cache
    # (lazy-populated on first miss).
    PR_CACHE_DIR="/tmp/claude-pr-cache"
    cur_repo_key=$(echo -n "$cur_repo" | md5sum | cut -d' ' -f1)
    cur_cache_file="${PR_CACHE_DIR}/${cur_repo_key}"
    cur_checked_file="${PR_CACHE_DIR}/${cur_repo_key}.checked"
    cur_pr=""
    if [ -f "$cur_cache_file" ]; then
      cur_pr=$(cat "$cur_cache_file")
    elif [ ! -f "$cur_checked_file" ] && [ -n "$cur_branch" ]; then
      mkdir -p "$PR_CACHE_DIR"
      touch "$cur_checked_file"
      cur_pr=$(cd "$cur_repo" && gh pr view --json url -q .url 2>/dev/null || true)
      [ -n "$cur_pr" ] && echo "$cur_pr" > "$cur_cache_file"
    fi

    short_cur=$(shorten "$cur_repo")
    br_label="${cur_branch:-no branch}"
    if [ -n "$cur_pr" ]; then
      cur_row=$(printf '%b▶ %s%b  %b%s%b  %b%s%b' \
        "$bold$blue" "$short_cur" "$reset" \
        "$green" "$br_label" "$reset" \
        "$purple" "$cur_pr" "$reset")
    else
      cur_row=$(printf '%b▶ %s%b  %b%s%b  %b(no PR)%b' \
        "$bold$blue" "$short_cur" "$reset" \
        "$green" "$br_label" "$reset" \
        "$dim" "$reset")
    fi
    # Append: blank line, then current row.
    out="${out}"$'\n'"${cur_row}"$'\n'
  fi

  ctx_line=""
  if [ -n "$used_int" ]; then
    ctx_line=$(printf '%b%s%%%b' "$dim" "$used_int" "$reset")
  fi

  printf '%b' "${out%$'\n'}"
  if [ -n "$ctx_line" ]; then
    printf '\n%b' "$ctx_line"
  fi
else
  # Fallback: single-line legacy behavior. Lazy-cache PR URL per repo.
  cwd_short=$(basename "$full_cwd")
  PR_CACHE_DIR="/tmp/claude-pr-cache"
  repo_key=$(echo -n "$full_cwd" | md5sum | cut -d' ' -f1)
  cache_file="${PR_CACHE_DIR}/${repo_key}"
  checked_file="${PR_CACHE_DIR}/${repo_key}.checked"

  pr_url=""
  if [ -f "$cache_file" ]; then
    pr_url=$(cat "$cache_file")
  elif [ ! -f "$checked_file" ] && [ -n "$cur_branch" ]; then
    mkdir -p "$PR_CACHE_DIR"
    touch "$checked_file"
    pr_url=$(cd "$full_cwd" && gh pr view --json url -q .url 2>/dev/null || true)
    if [ -n "$pr_url" ]; then
      echo "$pr_url" > "$cache_file"
    fi
  fi

  git_info=$([ -n "$cur_branch" ] && printf '  %b%s%b' "$green" "$cur_branch" "$reset" || echo '')
  pr_info=$([ -n "$pr_url" ] && printf ' %b%s%b' "$purple" "$pr_url" "$reset" || echo '')
  ctx_info=$([ -n "$used_int" ] && printf ' %b%s%%%b' "$dim" "$used_int" "$reset" || echo '')

  printf '%b%s%b%s%s%s' "$blue" "$cwd_short" "$reset" "$git_info" "$pr_info" "$ctx_info"
fi
