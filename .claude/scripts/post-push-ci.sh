#!/bin/bash
# PostToolUse hook: detect git push or PR creation and persist state.
#
# Captures the head branch from the invoking command (gh pr create -H,
# MCP create_pull_request .tool_input.head) so PRs created from a different
# checked-out branch are still tracked. Falls back to the current branch
# for plain `git push`.
#
# Side effects:
# 1. Writes /tmp/claude-ci-state/push-pending-<session_key> — the Stop hook
#    uses this to nudge Claude into spawning /babysit-ci and running
#    /refresh-pr-state before ending the turn.
# 2. Appends/updates rows in /tmp/claude-pr-state/<session_key> recording
#    (repo_root, branch, pr_url, base_branch, number, updated_at). The
#    statusline reads this to show every PR the session is tracking.
# 3. Caches PR URL per-repo at /tmp/claude-pr-cache/<repo_key> for the
#    statusline's single-line fallback when no session state exists.

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

is_push=false
is_create=false
if [ "$tool_name" = "Bash" ]; then
  if echo "$cmd" | grep -qE '(^|\s|&&|\||\;)gh\s+pr\s+create(\s|$)'; then
    is_push=true; is_create=true
  elif echo "$cmd" | grep -qE 'gh\s+api' \
    && echo "$cmd" | grep -q '/pulls' \
    && echo "$cmd" | grep -qE '-X\s+POST'; then
    is_push=true; is_create=true
  elif echo "$cmd" | grep -qE '(^|\s|&&|\||\;)git\s+push(\s|$)'; then
    is_push=true
  fi
elif [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  is_push=true; is_create=true
fi

if [ "$is_push" != "true" ]; then
  exit 0
fi

transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')
if [ -z "$transcript" ]; then
  exit 0
fi
session_key=$(echo -n "$transcript" | md5sum | cut -d' ' -f1)

cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  exit 0
fi

# Canonicalize to repo root so state keys stay stable regardless of subdir.
repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
[ -z "$repo_root" ] && repo_root="$cwd"

# Collect the head branches this tool call touched. Multiple may appear in
# one batched Bash command.
heads=""
if [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  mcp_head=$(echo "$input" | jq -r '.tool_input.head // empty')
  [ -n "$mcp_head" ] && heads="$mcp_head"
elif [ "$is_create" = "true" ]; then
  # Parse -H/--head from `gh pr create ...` and `gh api ... -X POST .../pulls -f head=...`.
  flags_heads=$(echo "$cmd" | grep -oE '(-H|--head)[[:space:]]+[^[:space:]]+' \
    | sed -E 's/^(-H|--head)[[:space:]]+//')
  api_heads=$(echo "$cmd" | grep -oE -- '-f[[:space:]]+head=[^[:space:]]+' \
    | sed -E 's/^-f[[:space:]]+head=//')
  combined=$(printf '%s\n%s' "$flags_heads" "$api_heads" | sed '/^$/d')
  [ -n "$combined" ] && heads=$(printf '%s' "$combined" | sort -u)
fi

# Fallback: no explicit head from the command — use the currently checked-out
# branch. Covers `gh pr create` with no -H (it defaults to current branch)
# and plain `git push`.
if [ -z "$heads" ]; then
  current_head=$(git -C "$repo_root" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -n "$current_head" ] && heads="$current_head"
fi

if [ -z "$heads" ]; then
  exit 0
fi

mkdir -p /tmp/claude-pr-state /tmp/claude-ci-state /tmp/claude-pr-cache
state_file="/tmp/claude-pr-state/$session_key"
ts=$(date +%s)
last_pr_url=""
repo_key=$(echo -n "$repo_root" | md5sum | cut -d' ' -f1)

# For each head branch, look up the PR and append/update a row.
while IFS= read -r head_branch; do
  [ -z "$head_branch" ] && continue
  pr_json=$(cd "$repo_root" && gh pr view "$head_branch" --json url,baseRefName,headRefName,number,state 2>/dev/null)
  [ -z "$pr_json" ] && continue

  state_=$(echo "$pr_json" | jq -r '.state // empty')
  # OPEN/DRAFT means trackable; CLOSED/MERGED PRs reachable via the head are skipped.
  if [ "$state_" != "OPEN" ] && [ "$state_" != "DRAFT" ]; then
    continue
  fi

  pr_url=$(echo "$pr_json" | jq -r '.url // empty')
  base_branch=$(echo "$pr_json" | jq -r '.baseRefName // empty')
  # Strip Spr/restack-style "-cached" mirror suffix so stack walking matches
  # the real parent branch.
  base_branch="${base_branch%-cached}"
  pr_head=$(echo "$pr_json" | jq -r '.headRefName // empty')
  number=$(echo "$pr_json" | jq -r '.number // empty')
  [ -z "$pr_url" ] && continue
  [ -z "$pr_head" ] && pr_head="$head_branch"

  new_row=$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$repo_root" "$pr_head" "$pr_url" "$base_branch" "$number" "$ts")

  if [ -f "$state_file" ]; then
    tmp=$(mktemp)
    awk -F'\t' -v r="$repo_root" -v b="$pr_head" '$1==r && $2==b {next} {print}' "$state_file" > "$tmp"
    mv "$tmp" "$state_file"
  fi
  printf '%s\n' "$new_row" >> "$state_file"

  last_pr_url="$pr_url"
done <<< "$heads"

if [ -n "$last_pr_url" ]; then
  echo "$last_pr_url" > /tmp/claude-ci-state/push-pending-"$session_key"
  echo "$last_pr_url" > /tmp/claude-pr-cache/"$repo_key"
fi

exit 0
