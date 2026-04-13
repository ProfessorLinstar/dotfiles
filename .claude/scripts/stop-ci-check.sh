#!/bin/bash
# Stop hook: block Claude from stopping if a git push was made without
# spawning a /babysit-ci agent. Uses session-scoped flag files so
# multiple Claude sessions don't interfere with each other.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')

if [ -z "$session_id" ]; then
  exit 0
fi

FLAG_FILE="$HOME/.claude/state/ci-pending-push-${session_id}"

if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi

pr_url=$(cat "$FLAG_FILE")

# Block: exit 2 sends stderr back to Claude as actionable feedback
echo "You pushed to a PR but haven't started CI monitoring yet. Before stopping, you MUST:" >&2
echo "1. Spawn a BACKGROUND agent to run /babysit-ci ${pr_url}" >&2
echo "2. After spawning the agent, delete the flag file: rm ${FLAG_FILE}" >&2
echo "Only then can you stop." >&2
exit 2
