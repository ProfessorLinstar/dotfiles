#!/bin/bash
# post-push-ci.sh negative cases: non-push commands, no transcript,
# gh pr view returns nothing, malformed JSON tolerated.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"

tx=$(mk_session neg)
sk=$(session_key_of "$tx")

# --- ls is not a push → no exit hook side effects
hook_input_bash "ls /tmp" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

# --- gh pr edit is not a push
hook_input_bash "gh pr edit 123 --title foo" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

# --- gh pr create but `gh pr view` returns empty → silently no-op
# (no fixture means our mock returns empty stdout)
hook_input_bash "gh pr create -H ghost" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"
assert_file_missing "$CI_DIR/push-pending-$sk"

# --- No transcript field → silently exits
echo '{"tool_name":"Bash","tool_input":{"command":"gh pr create -H foo"},"cwd":"'"$REPO"'","tool_response":{"success":true}}' \
  | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

# --- mcp create with no head → silently exits
echo '{"tool_name":"mcp__github__create_pull_request","tool_input":{},"cwd":"'"$REPO"'","transcript_path":"'"$tx"'","tool_response":{"success":true}}' \
  | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

echo "all negative checks ok"
