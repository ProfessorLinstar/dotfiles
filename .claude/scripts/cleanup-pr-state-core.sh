#!/bin/bash
# Core mutation for /cleanup-pr-state. Walks every per-session state file,
# drops MERGED/CLOSED/unreachable rows, deletes session files that end up
# empty, then prunes dangling _by_workspace pointers.
#
# Preserves rows on `gh` transport/auth failure — a network blip can't
# wipe cross-session state.

set -e

. "$(dirname "$0")/_lib.sh"

HELPER="$(dirname "$0")/pr-state.sh"

scanned=0
dropped_merged=0
dropped_closed=0
dropped_unreachable=0
files_deleted=0

shopt -s nullglob
for f in "$STATE_DIR"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in _*) continue ;; esac
  scanned=$((scanned + 1))

  new_rows=""
  while IFS=$'\t' read -r r br_ pr_ base_ num_; do
    [ -z "$r" ] && continue
    if gh_view_rc gh pr view "$pr_" --json state; then
      state_=$(printf '%s' "$REPLY" | jq -r '.state // empty')
      case "$state_" in
        OPEN|DRAFT) new_rows="${new_rows}$(emit_row "$r" "$br_" "$pr_" "$base_" "$num_")"$'\n' ;;
        MERGED)     dropped_merged=$((dropped_merged + 1)) ;;
        CLOSED)     dropped_closed=$((dropped_closed + 1)) ;;
        *)          dropped_unreachable=$((dropped_unreachable + 1)) ;;
      esac
    else
      # Transport / auth failure → preserve.
      new_rows="${new_rows}$(emit_row "$r" "$br_" "$pr_" "$base_" "$num_")"$'\n'
    fi
  done < "$f"

  if [ -z "$new_rows" ]; then
    bash "$HELPER" drop-state "$f"
    files_deleted=$((files_deleted + 1))
  else
    printf '%s' "$new_rows" | bash "$HELPER" write-rows "$f"
  fi
done
shopt -u nullglob

bash "$HELPER" prune-pointers

echo "cleanup: scanned=$scanned merged=$dropped_merged closed=$dropped_closed unreachable=$dropped_unreachable files_deleted=$files_deleted"
