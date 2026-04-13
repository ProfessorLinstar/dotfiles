#!/bin/bash
# PostToolUse hook: detect git push and trigger CI monitoring
# Reads tool call JSON from stdin, checks if it was a git push,
# and outputs a systemMessage to trigger /babysit-ci

input=$(cat)

# Extract the command that was run
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only trigger on git push commands
if ! echo "$cmd" | grep -qE '^\s*git\s+push'; then
  exit 0
fi

# Get the current working directory from the hook input
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  exit 0
fi

# Try to detect the PR and repo info
pr_info=$(cd "$cwd" && gh pr view --json number,url,headRefOid 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$pr_info" ]; then
  # No PR associated with current branch - nothing to monitor
  exit 0
fi

pr_number=$(echo "$pr_info" | jq -r '.number')
pr_url=$(echo "$pr_info" | jq -r '.url')
head_sha=$(echo "$pr_info" | jq -r '.headRefOid')

# Extract owner/repo from the PR URL
# URL format: https://github.palantir.build/owner/repo/pull/123
# or: https://github.com/owner/repo/pull/123
repo_info=$(echo "$pr_url" | sed -E 's|https?://[^/]+/([^/]+)/([^/]+)/pull/[0-9]+|\1/\2|')
owner=$(echo "$repo_info" | cut -d'/' -f1)
repo=$(echo "$repo_info" | cut -d'/' -f2)

# Extract hostname for GHE support
hostname=$(echo "$pr_url" | sed -E 's|https?://([^/]+)/.*|\1|')

cat <<EOF
{"systemMessage": "A git push was just completed for PR #${pr_number} (${pr_url}). You should now spawn a background agent to monitor CI status for this PR. Use /babysit-ci ${pr_url} or invoke the babysit-ci command to start polling. The agent should run in the background so the user can continue working."}
EOF
