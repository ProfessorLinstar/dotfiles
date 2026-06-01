#!/bin/bash
# Claude Code statusLine script.
# Renders the per-session list of PRs Claude is tracking, with the
# currently-checked-out (repo, branch) highlighted. Falls back to a
# single-line cwd/branch/pr view when no session state exists.
#
# Maintains ~/.local/state/claude/pr-state/_by_workspace/<md5(workspace)>
# as a pointer to the active session_key so /refresh-pr-state and other
# slash commands can find this session's state file.
#
# Tunables (env vars):
#   CLAUDE_STATUSLINE_MAX_ROWS  Max tracked rows before "+N more" cap. (10)

input=$(cat)

full_cwd=$(echo "$input" | jq -r '.workspace.current_dir')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_int=$([ -n "$used" ] && printf '%.0f' "$used" || echo '')
transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')

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

# ANSI palette (printed via %s, never %b, so the data we print can never
# inject escapes itself).
ESC=$'\033'
blue="${ESC}[34m"
green="${ESC}[32m"
purple="${ESC}[35m"
dim="${ESC}[2m"
bold="${ESC}[1m"
reset="${ESC}[0m"

MAX_ROWS="${CLAUDE_STATUSLINE_MAX_ROWS:-10}"

session_key=""
STATE_DIR="$HOME/.local/state/claude/pr-state"
state_file=""
if [ -n "$transcript" ]; then
  session_key=$(printf '%s' "$transcript" | md5sum | cut -d' ' -f1)
  state_file="$STATE_DIR/$session_key"
  if [ -n "$full_cwd" ] && [ -n "$HOME" ]; then
    mkdir -p "$STATE_DIR/_by_workspace" 2>/dev/null
    ws_key=$(printf '%s' "$full_cwd" | md5sum | cut -d' ' -f1)
    echo "$session_key" > "$STATE_DIR/_by_workspace/$ws_key" 2>/dev/null

    # Opportunistically prune dangling pointers (roughly once per 20 renders).
    if [ $((RANDOM % 20)) -eq 0 ]; then
      for ptr in "$STATE_DIR/_by_workspace"/*; do
        [ -f "$ptr" ] || continue
        sk=$(cat "$ptr" 2>/dev/null)
        case "$sk" in
          */*|*..*|"") rm -f "$ptr" ;;
          *) [ -f "$STATE_DIR/$sk" ] || rm -f "$ptr" ;;
        esac
      done
    fi
  fi
fi

# Pick a PR-cache URL for (repo, branch). Empty if not yet known.
pr_cache_lookup() {
  local repo="$1" branch="$2"
  local key
  key=$(printf '%s' "$repo" | md5sum | cut -d' ' -f1)
  local f="$HOME/.local/state/claude/pr-cache/${key}_${branch}"
  if [ -f "$f" ]; then
    cat "$f"
  fi
}

# Lazy fill the cache for (repo, branch) on first miss. Marker file prevents
# repeated misses for the same (repo, branch) when no PR exists.
pr_cache_fill() {
  local repo="$1" branch="$2"
  [ -z "$branch" ] && return
  local key
  key=$(printf '%s' "$repo" | md5sum | cut -d' ' -f1)
  local dir="$HOME/.local/state/claude/pr-cache"
  local f="$dir/${key}_${branch}"
  local marker="$dir/${key}_${branch}.checked"
  if [ -f "$f" ] || [ -f "$marker" ]; then
    return
  fi
  mkdir -p "$dir"
  touch "$marker"
  local url
  url=$(cd "$repo" && gh pr view "$branch" --json url -q .url 2>/dev/null || true)
  if [ -n "$url" ]; then
    echo "$url" > "$f"
  fi
}

if [ -n "$state_file" ] && [ -s "$state_file" ]; then
  # Stack-sort rows by (repo asc, stack depth asc).
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

  # Collect rows into arrays first so we can apply the vertical cap and find
  # the current row's index regardless of position.
  rows_repo=()
  rows_branch=()
  rows_url=()
  rows_base=()
  rows_num=()
  cur_idx=-1
  while IFS=$'\t' read -r r br_ pr_ base_ num_ ts_; do
    [ -z "$r" ] && continue
    rows_repo+=("$r")
    rows_branch+=("$br_")
    rows_url+=("$pr_")
    rows_base+=("$base_")
    rows_num+=("$num_")
    if [ "$r" = "$cur_repo" ] && [ "$br_" = "$cur_branch" ]; then
      cur_idx=$(( ${#rows_repo[@]} - 1 ))
    fi
  done <<< "$sorted"

  n=${#rows_repo[@]}

  # Build the index list of rows to render under the cap.
  visible=()
  if [ "$n" -le "$MAX_ROWS" ]; then
    for ((i=0; i<n; i++)); do visible+=("$i"); done
    truncated_count=0
  else
    keep=$((MAX_ROWS - 1))
    for ((i=0; i<keep; i++)); do visible+=("$i"); done
    truncated_count=$((n - keep))
    # If the current row is outside the visible window, swap it into the
    # last visible slot so the user can always see "where they are".
    if [ "$cur_idx" -ge 0 ]; then
      in_visible=0
      for v in "${visible[@]}"; do
        [ "$v" = "$cur_idx" ] && in_visible=1
      done
      if [ "$in_visible" -eq 0 ] && [ "$keep" -gt 0 ]; then
        visible[$((keep-1))]=$cur_idx
      fi
    fi
  fi

  out=""
  shown_current=0
  for vi in "${visible[@]}"; do
    r="${rows_repo[$vi]}"
    br_="${rows_branch[$vi]}"
    pr_="${rows_url[$vi]}"
    short_r=$(shorten "$r")

    if [ "$r" = "$cur_repo" ] && [ "$br_" = "$cur_branch" ]; then
      shown_current=1
      line="${bold}${blue}▶ ${short_r}${reset}  ${green}${br_}${reset}  ${purple}${pr_}${reset}"
    else
      line="${dim}  ${short_r}  ${br_}  ${pr_}${reset}"
    fi
    out="${out}${line}"$'\n'
  done

  if [ "$truncated_count" -gt 0 ]; then
    out="${out}${dim}  … +${truncated_count} more${reset}"$'\n'
  fi

  # If the current (repo, branch) isn't part of the tracked stack at all,
  # render it as a separate block below with a blank-line separator.
  if [ "$shown_current" -eq 0 ] && [ -n "$cur_repo" ]; then
    pr_cache_fill "$cur_repo" "$cur_branch"
    cur_pr=$(pr_cache_lookup "$cur_repo" "$cur_branch")

    short_cur=$(shorten "$cur_repo")
    br_label="${cur_branch:-no branch}"
    if [ -n "$cur_pr" ]; then
      cur_row="${bold}${blue}▶ ${short_cur}${reset}  ${green}${br_label}${reset}  ${purple}${cur_pr}${reset}"
    else
      cur_row="${bold}${blue}▶ ${short_cur}${reset}  ${green}${br_label}${reset}  ${dim}(no PR)${reset}"
    fi
    out="${out}"$'\n'"${cur_row}"$'\n'
  fi

  ctx_line=""
  if [ -n "$used_int" ]; then
    ctx_line="${dim}${used_int}%${reset}"
  fi

  printf '%s' "${out%$'\n'}"
  if [ -n "$ctx_line" ]; then
    printf '\n%s' "$ctx_line"
  fi
else
  # Fallback: single-line legacy view.
  cwd_short=$(basename "$full_cwd")
  pr_cache_fill "$cur_repo" "$cur_branch"
  pr_url=$(pr_cache_lookup "$cur_repo" "$cur_branch")

  git_info=""
  if [ -n "$cur_branch" ]; then
    git_info="  ${green}${cur_branch}${reset}"
  fi
  pr_info=""
  if [ -n "$pr_url" ]; then
    pr_info=" ${purple}${pr_url}${reset}"
  fi
  ctx_info=""
  if [ -n "$used_int" ]; then
    ctx_info=" ${dim}${used_int}%${reset}"
  fi
  printf '%s%s%s%s%s%s' "$blue" "$cwd_short" "$reset" "$git_info" "$pr_info" "$ctx_info"
fi
