#!/bin/bash
# PostToolUse hook: detect git push and persist a flag for the Stop hook.
# The Stop hook will block Claude from stopping until it spawns /babysit-ci.
# Uses session_id to scope flags so multiple Claude sessions don't collide.

input=$(cat)

# Extract the command that was run
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only trigger on git push commands
if ! echo "$cmd" | grep -qE '^\s*git\s+push'; then
  exit 0
fi

# Get session ID and working directory
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ] || [ -z "$session_id" ]; then
  exit 0
fi

# Try to detect the PR and repo info
pr_info=$(cd "$cwd" && gh pr view --json number,url,headRefOid 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$pr_info" ]; then
  # No PR associated with current branch - nothing to monitor
  exit 0
fi

pr_url=$(echo "$pr_info" | jq -r '.url')

# Write session-scoped flag file for the Stop hook to pick up
mkdir -p ~/.claude/state
echo "$pr_url" > ~/.claude/state/ci-pending-push-"$session_id"

exit 0
