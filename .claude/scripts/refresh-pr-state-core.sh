#!/bin/bash
# Core mutation for /refresh-pr-state.
#
# Usage:  refresh-pr-state-core.sh <state_file_path>
# Stdin:  <pr_url>\t<repo_root> per line (PRs Claude observed but the
#         hook may have missed). Combined with pr-log/<session_key>.
#
# Effect:
#   1. Re-queries every existing row by pr_url. Drops MERGED/CLOSED.
#      Refreshes base_branch (strips -cached). PRESERVES rows when gh
#      exits non-zero (transport / auth failure) — a network blip won't
#      wipe state.
#   2. Adds stdin + log-derived PRs if OPEN/DRAFT and not duplicate.
#   3. Atomic rewrite via pr-state.sh write-rows.
#   4. Clears push-pending flag.

set -e

. "$(dirname "$0")/_lib.sh"

STATE_FILE="${1:-}"
[ -z "$STATE_FILE" ] && { echo "refresh-pr-state-core: missing state file path" >&2; exit 1; }
case "$STATE_FILE" in "$STATE_DIR"/*) : ;; *) echo "refresh-pr-state-core: refusing path outside $STATE_DIR" >&2; exit 1 ;; esac

HELPER="$(dirname "$0")/pr-state.sh"

existing=""
[ -s "$STATE_FILE" ] && existing=$(cat "$STATE_FILE")
stdin_input=$(cat)

kept=0
preserved_count=0
dropped_urls=""
added_urls=""
tracked_urls=""
new_rows=""

# --- Phase 1: re-query each existing row.
while IFS=$'\t' read -r r br_ pr_ base_ num_; do
  [ -z "$r" ] && continue
  if gh_pr_view_full "$pr_"; then
    case "$PR_STATE" in
      OPEN|DRAFT)
        [ -z "$PR_HEAD" ] && PR_HEAD="$br_"
        [ -z "$PR_NUMBER" ] && PR_NUMBER="$num_"
        new_rows="${new_rows}$(emit_row "$r" "$PR_HEAD" "$pr_" "$PR_BASE" "$PR_NUMBER")"$'\n'
        tracked_urls="$tracked_urls $pr_"
        kept=$((kept + 1))
        ;;
      "")
        # gh exit 0 with empty stdout — treat as gone.
        dropped_urls="$dropped_urls $pr_(unreachable)"
        ;;
      *)
        dropped_urls="$dropped_urls $pr_($PR_STATE)"
        ;;
    esac
  else
    # Transport / auth failure — keep the row as-is.
    new_rows="${new_rows}$(emit_row "$r" "$br_" "$pr_" "$base_" "$num_")"$'\n'
    tracked_urls="$tracked_urls $pr_"
    preserved_count=$((preserved_count + 1))
    kept=$((kept + 1))
  fi
done <<< "$existing"

# --- Phase 2: combine stdin seeds with PR-log seeds.
session_key=$(basename "$STATE_FILE")
log_file="$LOG_DIR/$session_key"
combined_input="$stdin_input"
if [ -f "$log_file" ]; then
  # Last entry per URL wins (keep latest repo_root association).
  log_lines=$(awk -F'\t' '{ latest[$2] = $2 "\t" $3 } END { for (k in latest) print latest[k] }' "$log_file")
  if [ -n "$log_lines" ]; then
    combined_input="${combined_input}${combined_input:+$'\n'}${log_lines}"
  fi
fi

# --- Phase 3: add seeds not already tracked.
while IFS=$'\t' read -r in_url in_repo; do
  [ -z "$in_url" ] || [ -z "$in_repo" ] && continue
  case " $tracked_urls " in *" $in_url "*) continue ;; esac
  if ! gh_pr_view_full "$in_url"; then continue; fi
  case "$PR_STATE" in OPEN|DRAFT) ;; *) continue ;; esac
  [ -z "$PR_HEAD" ] && continue
  new_rows="${new_rows}$(emit_row "$in_repo" "$PR_HEAD" "$in_url" "$PR_BASE" "$PR_NUMBER")"$'\n'
  tracked_urls="$tracked_urls $in_url"
  added_urls="$added_urls $in_url"
done <<< "$combined_input"

# --- Write back and clear flag.
printf '%s' "$new_rows" | bash "$HELPER" write-rows "$STATE_FILE"
bash "$HELPER" clear-flag "$session_key" 2>/dev/null || true

added_count=$(wc -w <<< "$added_urls")
dropped_count=$(wc -w <<< "$dropped_urls")

echo "refresh: kept=$kept added=$added_count dropped=$dropped_count preserved=$preserved_count"
if [ -n "$dropped_urls" ]; then echo "  dropped:$dropped_urls"; fi
if [ -n "$added_urls" ]; then echo "  added:$added_urls"; fi
if [ "$preserved_count" -gt 0 ]; then echo "  preserved (gh transport failure — row kept as-is)"; fi
