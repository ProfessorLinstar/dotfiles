#!/bin/bash
# Stop hook: if a push happened this session and the push-pending flag
# hasn't been cleared, block Claude from stopping until it spawns
# /babysit-ci and runs /refresh-pr-state. Both actions must run, then the
# flag file is deleted.

input=$(cat)

transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')
if [ -z "$transcript" ]; then
  exit 0
fi
session_key=$(echo -n "$transcript" | md5sum | cut -d' ' -f1)

FLAG_FILE="$HOME/.local/state/claude/ci-state/push-pending-${session_key}"

if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi

pr_url=$(cat "$FLAG_FILE")

echo "You pushed to a PR but haven't finished post-push follow-up. Before stopping, you MUST:" >&2
echo "1. Spawn a BACKGROUND agent to run /babysit-ci ${pr_url}" >&2
echo "2. Run /refresh-pr-state to update the PR stack order in the statusline" >&2
echo "3. After both, clear the flag: bash ~/.claude/scripts/pr-state.sh clear-flag ${session_key}" >&2
echo "Only then can you stop." >&2
exit 2
