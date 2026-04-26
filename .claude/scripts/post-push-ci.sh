#!/bin/bash
# PostToolUse hook: detect git push or PR creation and persist a flag for the Stop hook.
# The Stop hook will block Claude from stopping until it spawns /babysit-ci.
# Uses transcript_path hash for session scoping (available in all hook events).

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# Detect: git push (Bash) or gh pr create (Bash) or MCP PR creation
is_push=false
if [ "$tool_name" = "Bash" ]; then
  if echo "$cmd" | grep -qE '(^|\s|&&|\||\;)git\s+push(\s|$)'; then
    is_push=true
  elif echo "$cmd" | grep -qE '(^|\s|&&|\||\;)gh\s+pr\s+create(\s|$)'; then
    is_push=true
  fi
elif [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  is_push=true
fi

if [ "$is_push" != "true" ]; then
  exit 0
fi

# Derive a stable session key from transcript_path (unique per session, available in all hooks)
transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')
if [ -z "$transcript" ]; then
  exit 0
fi
session_key=$(echo -n "$transcript" | md5sum | cut -d' ' -f1)

# Get the current working directory from the hook input
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  exit 0
fi

# Try to detect the PR URL
pr_url=""

if [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  # For MCP tool, the PR URL is in the tool result
  pr_url=$(echo "$input" | jq -r '.tool_result // empty' | grep -oE 'https://[^ ]*pull/[0-9]+' | head -1)
fi

# Fallback: detect from current branch
if [ -z "$pr_url" ]; then
  pr_info=$(cd "$cwd" && gh pr view --json url -q .url 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$pr_info" ]; then
    pr_url="$pr_info"
  fi
fi

if [ -z "$pr_url" ]; then
  exit 0
fi

# Write session-scoped flag file for the Stop hook to pick up
mkdir -p /tmp/claude-ci-state
echo "$pr_url" > /tmp/claude-ci-state/ci-pending-push-"$session_key"

# Cache PR URL per-repo for the statusline (separate dir so babysit-ci cleanup won't affect it)
repo_key=$(echo -n "$cwd" | md5sum | cut -d' ' -f1)
mkdir -p /tmp/claude-pr-cache
echo "$pr_url" > /tmp/claude-pr-cache/"$repo_key"

exit 0
