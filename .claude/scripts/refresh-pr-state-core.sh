#!/bin/bash
# Core mutation for /refresh-pr-state. Called by the slash command after
# Claude has decided which session-relevant PRs to add from conversation
# context. Keeps the I/O deterministic and unit-testable.
#
# Usage:
#   refresh-pr-state-core.sh <state_file_path>
#
# Stdin: zero or more lines of `<pr_url>\t<repo_root>`. These are PRs Claude
# observed in the conversation that aren't yet tracked. The script queries
# each one and appends if OPEN/DRAFT.
#
# Effect:
#   1. Re-queries every row currently in the state file by its pr_url.
#      Drops MERGED/CLOSED. Refreshes base_branch (strips -cached).
#   2. For each (pr_url, repo_root) on stdin, adds a row if OPEN/DRAFT and
#      not already tracked. repo_root is used verbatim from the input.
#   3. Atomic rewrite via pr-state.sh write-rows.
#   4. Clears the push-pending flag for the session_key derived from the
#      state file's basename.
#
# Output: a short summary (kept, dropped, added).

set -e

STATE_FILE="${1:-}"
if [ -z "$STATE_FILE" ]; then
  echo "refresh-pr-state-core: missing state file path" >&2
  exit 1
fi

HELPER="$(dirname "$0")/pr-state.sh"
STATE_DIR=$(bash "$HELPER" state-dir)
CI_DIR=$(bash "$HELPER" ci-dir)
LOG_DIR="$HOME/.local/state/claude/pr-log"
case "$STATE_FILE" in
  "$STATE_DIR"/*) : ;;
  *) echo "refresh-pr-state-core: refusing path outside $STATE_DIR" >&2; exit 1 ;;
esac

ts=$(date +%s)

# Read existing rows, then collect input rows from stdin.
existing=""
if [ -s "$STATE_FILE" ]; then
  existing=$(cat "$STATE_FILE")
fi
stdin_input=$(cat)

kept=0
dropped_urls=""
added_urls=""
tracked_urls=""

new_rows=""

emit_row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}

# Re-query each existing row. Distinguish transport/auth failure (`gh` exits
# non-zero — preserve the row) from "PR not found / merged / closed" (`gh`
# exits 0 with a definite state — drop). A network blip should never wipe
# state.
preserved_count=0
while IFS=$'\t' read -r r br_ pr_ base_ num_ old_ts; do
  [ -z "$r" ] && continue
  # Use `if` so `set -e` doesn't kill the script when gh exits non-zero
  # (transport / auth failure) — we want to capture that and preserve the row.
  if json=$(gh pr view "$pr_" --json url,baseRefName,headRefName,number,state 2>/dev/null); then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    # Transport / auth failure — keep the existing row verbatim and move on.
    row=$(emit_row "$r" "$br_" "$pr_" "$base_" "$num_" "$old_ts")
    new_rows="${new_rows}${row}"$'\n'
    tracked_urls="$tracked_urls $pr_"
    preserved_count=$((preserved_count + 1))
    kept=$((kept + 1))
    continue
  fi
  if [ -z "$json" ]; then
    # gh exited 0 with empty stdout — odd, but treat as "definitely gone".
    dropped_urls="$dropped_urls $pr_(unreachable)"
    continue
  fi
  state_=$(printf '%s' "$json" | jq -r '.state // empty')
  case "$state_" in
    OPEN|DRAFT)
      base=$(printf '%s' "$json" | jq -r '.baseRefName // empty')
      base="${base%-cached}"
      head=$(printf '%s' "$json" | jq -r '.headRefName // empty')
      number=$(printf '%s' "$json" | jq -r '.number // empty')
      [ -z "$head" ] && head="$br_"
      [ -z "$number" ] && number="$num_"
      row=$(emit_row "$r" "$head" "$pr_" "$base" "$number" "$ts")
      new_rows="${new_rows}${row}"$'\n'
      tracked_urls="$tracked_urls $pr_"
      kept=$((kept + 1))
      ;;
    *)
      dropped_urls="$dropped_urls $pr_($state_)"
      ;;
  esac
done <<< "$existing"

# Pull seeds from the PR log too (hook-observed PRs survive compaction).
log_seeds=""
session_key=$(basename "$STATE_FILE")
log_file="$LOG_DIR/$session_key"
if [ -f "$log_file" ]; then
  # Each line: ts \t pr_url \t repo_root \t head \t source. Keep latest per URL.
  log_seeds=$(awk -F'\t' '
    { latest[$2]=$0 }
    END { for (k in latest) print latest[k] }
  ' "$log_file")
fi

# Combine: explicit stdin from caller takes precedence over the log
# (caller may have repo_root info we don't).
combined_input=""
if [ -n "$stdin_input" ]; then
  combined_input="$stdin_input"
fi
if [ -n "$log_seeds" ]; then
  while IFS=$'\t' read -r _ts log_url log_repo _log_head _src; do
    [ -z "$log_url" ] && continue
    combined_input="${combined_input}${log_url}"$'\t'"${log_repo}"$'\n'
  done <<< "$log_seeds"
fi

# Add combined rows not already tracked.
while IFS=$'\t' read -r in_url in_repo; do
  [ -z "$in_url" ] && continue
  [ -z "$in_repo" ] && continue
  case " $tracked_urls " in
    *" $in_url "*) continue ;;
  esac
  json=$(gh pr view "$in_url" --json url,baseRefName,headRefName,number,state 2>/dev/null || true)
  [ -z "$json" ] && continue
  state_=$(printf '%s' "$json" | jq -r '.state // empty')
  case "$state_" in
    OPEN|DRAFT)
      base=$(printf '%s' "$json" | jq -r '.baseRefName // empty')
      base="${base%-cached}"
      head=$(printf '%s' "$json" | jq -r '.headRefName // empty')
      number=$(printf '%s' "$json" | jq -r '.number // empty')
      [ -z "$head" ] && continue
      row=$(emit_row "$in_repo" "$head" "$in_url" "$base" "$number" "$ts")
      new_rows="${new_rows}${row}"$'\n'
      tracked_urls="$tracked_urls $in_url"
      added_urls="$added_urls $in_url"
      ;;
  esac
done <<< "$combined_input"

# Write back.
printf '%s' "$new_rows" | bash "$HELPER" write-rows "$STATE_FILE"

# Clear push-pending flag.
session_key=$(basename "$STATE_FILE")
bash "$HELPER" clear-flag "$session_key" 2>/dev/null || true

added_count=0
for _ in $added_urls; do added_count=$((added_count + 1)); done
dropped_count=0
for _ in $dropped_urls; do dropped_count=$((dropped_count + 1)); done

echo "refresh: kept=$kept added=$added_count dropped=$dropped_count preserved=$preserved_count"
if [ -n "$dropped_urls" ]; then echo "  dropped:$dropped_urls"; fi
if [ -n "$added_urls" ]; then echo "  added:$added_urls"; fi
if [ "$preserved_count" -gt 0 ]; then echo "  preserved (gh transport failure — row kept as-is)"; fi
