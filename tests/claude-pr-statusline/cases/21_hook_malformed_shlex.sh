#!/bin/bash
# Malformed shell commands (unmatched quote) must not crash the hook —
# python3 shlex raises ValueError and we exit 0 silently.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"

tx=$(mk_session bad)
sk=$(session_key_of "$tx")

# Unmatched single quote
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"echo '\''unclosed"},"cwd":"'"$REPO"'","transcript_path":"'"$tx"'","tool_response":{"success":true}}' \
  | bash "$HOOK"
rc=$?
set -e
assert_equal "$rc" "0" "hook exits 0 on unmatched quote"
assert_file_missing "$STATE_DIR/$sk"

# Unmatched double quote in a command that looks like gh pr create
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"gh pr create -H \"unclosed"},"cwd":"'"$REPO"'","transcript_path":"'"$tx"'","tool_response":{"success":true}}' \
  | bash "$HOOK"
rc=$?
set -e
assert_equal "$rc" "0" "hook exits 0 on unmatched double quote"
assert_file_missing "$STATE_DIR/$sk"

echo "malformed shlex ok"
