#!/bin/bash
# Core mutation for /discover-pr-state. Walks the parent/child chain from
# each seed row using `gh pr list` to find sibling PRs in the same stack.
#
# Usage:
#   discover-pr-state-core.sh <state_file_path>
#
# Stdin: zero or more seed rows in the same TSV shape as the state file
# (`repo_root\tbranch\tpr_url\tbase_branch\tnumber\tupdated_at`). These are
# the rows Claude picks (conversation context first, then existing state).
#
# Effect:
#   1. Reads existing state rows and stdin seeds into a working set.
#   2. For each seed, walks up via `gh pr list --head <base_branch>` (one
#      hop = single match) and down via `gh pr list --base <branch>`
#      (multiple OK). Adds any open PRs found, recurses.
#   3. Stops at main-line branches (main/master/develop/trunk) for up-walk.
#   4. Caps at 20 new PRs per repo.
#   5. Atomic writeback via pr-state.sh write-rows.
#
# Output: short summary.

set -e

STATE_FILE="${1:-}"
if [ -z "$STATE_FILE" ]; then
  echo "discover-pr-state-core: missing state file path" >&2
  exit 1
fi

HELPER="$(dirname "$0")/pr-state.sh"
STATE_DIR=$(bash "$HELPER" state-dir)
case "$STATE_FILE" in
  "$STATE_DIR"/*) : ;;
  *) echo "discover-pr-state-core: refusing path outside $STATE_DIR" >&2; exit 1 ;;
esac

CAP_PER_REPO=20
ts=$(date +%s)
seeds_stdin=$(cat)

# Build the in-memory rows list and (repo, branch) set.
declare -A tracked
all_rows=""

ingest_row() {
  local r="$1" br_="$2" pr_="$3" base_="$4" num_="$5"
  local k="${r}|${br_}"
  if [ -n "${tracked[$k]:-}" ]; then
    return 1
  fi
  tracked[$k]=1
  all_rows="${all_rows}${r}"$'\t'"${br_}"$'\t'"${pr_}"$'\t'"${base_}"$'\t'"${num_}"$'\t'"${ts}"$'\n'
  return 0
}

# Existing rows.
if [ -s "$STATE_FILE" ]; then
  while IFS=$'\t' read -r r br_ pr_ base_ num_ _; do
    [ -z "$r" ] && continue
    ingest_row "$r" "$br_" "$pr_" "$base_" "$num_" || true
  done < "$STATE_FILE"
fi

# Working set we walk from = seeds (stdin) ∪ existing rows.
working=""
if [ -s "$STATE_FILE" ]; then
  working=$(cat "$STATE_FILE")
fi
if [ -n "$seeds_stdin" ]; then
  if [ -n "$working" ]; then
    working="${working}"$'\n'"$seeds_stdin"
  else
    working="$seeds_stdin"
  fi
fi

# Apply seeds from stdin first (these may not be in existing).
while IFS=$'\t' read -r r br_ pr_ base_ num_ _; do
  [ -z "$r" ] && continue
  ingest_row "$r" "$br_" "$pr_" "$base_" "$num_" || true
done <<< "$seeds_stdin"

declare -A per_repo_count
discovered_count=0
bails=""

is_mainline() {
  case "$1" in
    main|master|develop|trunk) return 0 ;;
    *) return 1 ;;
  esac
}

# Walk up: find a single PR whose head = $base_branch.
walk_up() {
  local repo="$1" cur_base="$2"
  while [ -n "$cur_base" ]; do
    cur_base="${cur_base%-cached}"
    if is_mainline "$cur_base"; then
      return
    fi
    if [ "${per_repo_count[$repo]:-0}" -ge "$CAP_PER_REPO" ]; then
      bails="$bails cap-up($repo)"
      return
    fi
    local json
    json=$(cd "$repo" 2>/dev/null && gh pr list --head "$cur_base" --state open --json url,baseRefName,headRefName,number 2>/dev/null || true)
    [ -z "$json" ] && return
    local count
    count=$(printf '%s' "$json" | jq 'length')
    if [ "$count" != "1" ]; then
      [ "$count" != "0" ] && bails="$bails up-ambig($cur_base,$count)"
      return
    fi
    local p_url p_head p_base p_num
    p_url=$(printf '%s' "$json" | jq -r '.[0].url')
    p_head=$(printf '%s' "$json" | jq -r '.[0].headRefName')
    p_base=$(printf '%s' "$json" | jq -r '.[0].baseRefName')
    p_base="${p_base%-cached}"
    p_num=$(printf '%s' "$json" | jq -r '.[0].number')
    if ingest_row "$repo" "$p_head" "$p_url" "$p_base" "$p_num"; then
      per_repo_count[$repo]=$(( ${per_repo_count[$repo]:-0} + 1 ))
      discovered_count=$((discovered_count + 1))
    fi
    cur_base="$p_base"
  done
}

# Walk down: find PRs whose base = $branch. May return multiple → recurse on each.
walk_down() {
  local repo="$1" cur_branch="$2"
  [ -z "$cur_branch" ] && return
  if [ "${per_repo_count[$repo]:-0}" -ge "$CAP_PER_REPO" ]; then
    bails="$bails cap-down($repo)"
    return
  fi
  local json
  json=$(cd "$repo" 2>/dev/null && gh pr list --base "$cur_branch" --state open --json url,baseRefName,headRefName,number 2>/dev/null || true)
  [ -z "$json" ] && return
  local n
  n=$(printf '%s' "$json" | jq 'length')
  [ "$n" = "0" ] && return
  local i=0
  while [ "$i" -lt "$n" ]; do
    local c_url c_head c_base c_num
    c_url=$(printf '%s' "$json" | jq -r ".[$i].url")
    c_head=$(printf '%s' "$json" | jq -r ".[$i].headRefName")
    c_base=$(printf '%s' "$json" | jq -r ".[$i].baseRefName")
    c_base="${c_base%-cached}"
    c_num=$(printf '%s' "$json" | jq -r ".[$i].number")
    if ingest_row "$repo" "$c_head" "$c_url" "$c_base" "$c_num"; then
      per_repo_count[$repo]=$(( ${per_repo_count[$repo]:-0} + 1 ))
      discovered_count=$((discovered_count + 1))
      walk_down "$repo" "$c_head"
    fi
    i=$((i + 1))
  done
}

# Run walks on the original working set (not the growing one — keeps termination simple).
seed_set=""
if [ -s "$STATE_FILE" ]; then
  seed_set=$(cat "$STATE_FILE")
fi
if [ -n "$seeds_stdin" ]; then
  if [ -n "$seed_set" ]; then
    seed_set="${seed_set}"$'\n'"$seeds_stdin"
  else
    seed_set="$seeds_stdin"
  fi
fi
while IFS=$'\t' read -r r br_ pr_ base_ num_ _; do
  [ -z "$r" ] && continue
  walk_up "$r" "$base_"
  walk_down "$r" "$br_"
done <<< "$seed_set"

# Write back the merged rows.
printf '%s' "$all_rows" | bash "$HELPER" write-rows "$STATE_FILE"

echo "discover: added=$discovered_count"
if [ -n "$bails" ]; then
  echo "  bails:$bails"
fi
