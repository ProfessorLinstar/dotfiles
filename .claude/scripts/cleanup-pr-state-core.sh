#!/bin/bash
# Core mutation for /cleanup-pr-state. Walks every per-session state file,
# drops MERGED/CLOSED/unreachable rows, deletes session files that end up
# empty, then prunes dangling _by_workspace pointers.
#
# No args, no stdin. Output: short summary.

set -e

HELPER="$(dirname "$0")/pr-state.sh"
STATE_DIR=$(bash "$HELPER" state-dir)

scanned=0
dropped_merged=0
dropped_closed=0
dropped_unreachable=0
files_deleted=0

for f in "$STATE_DIR"/*; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    _*) continue ;;
  esac
  scanned=$((scanned + 1))

  ts=$(date +%s)
  new_rows=""
  while IFS=$'\t' read -r r br_ pr_ base_ num_ old_ts; do
    [ -z "$r" ] && continue
    json=$(gh pr view "$pr_" --json state 2>/dev/null || true)
    if [ -z "$json" ]; then
      dropped_unreachable=$((dropped_unreachable + 1))
      continue
    fi
    state_=$(printf '%s' "$json" | jq -r '.state // empty')
    case "$state_" in
      OPEN|DRAFT)
        new_rows="${new_rows}${r}"$'\t'"${br_}"$'\t'"${pr_}"$'\t'"${base_}"$'\t'"${num_}"$'\t'"${ts}"$'\n'
        ;;
      MERGED) dropped_merged=$((dropped_merged + 1)) ;;
      CLOSED) dropped_closed=$((dropped_closed + 1)) ;;
      *) dropped_unreachable=$((dropped_unreachable + 1)) ;;
    esac
  done < "$f"

  if [ -z "$new_rows" ]; then
    bash "$HELPER" drop-state "$f"
    files_deleted=$((files_deleted + 1))
  else
    printf '%s' "$new_rows" | bash "$HELPER" write-rows "$f"
  fi
done

bash "$HELPER" prune-pointers

echo "cleanup: scanned=$scanned merged=$dropped_merged closed=$dropped_closed unreachable=$dropped_unreachable files_deleted=$files_deleted"
