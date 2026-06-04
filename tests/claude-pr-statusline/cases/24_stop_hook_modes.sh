#!/bin/bash
# Stop hook: soft default, strict opt-in, TTL auto-expiry.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

STOP="$SCRIPTS_ROOT/stop-ci-check.sh"
CI_DIR="$HOME/.local/state/claude/ci-state"
mkdir -p "$CI_DIR"

tx=$(mk_session stop)
sk=$(session_key_of "$tx")
FLAG="$CI_DIR/push-pending-$sk"

# --- No flag → silent exit 0
set +e
out=$(printf '{"transcript_path":"%s"}\n' "$tx" | bash "$STOP" 2>&1)
rc=$?
set -e
assert_equal "$rc" "0" "no-flag → exit 0"
assert_equal "$out" "" "no-flag → no output"

# --- Flag present, soft default → exit 0 + stderr
echo "https://example.com/pr/9" > "$FLAG"
set +e
out=$(printf '{"transcript_path":"%s"}\n' "$tx" | bash "$STOP" 2>&1)
rc=$?
set -e
assert_equal "$rc" "0" "soft mode → exit 0"
assert_contains "$out" "https://example.com/pr/9" "soft mode shows URL"
assert_contains "$out" "/babysit-ci" "soft mode names /babysit-ci"
# Flag NOT cleared by soft mode (a later /refresh-pr-state does it)
assert_file_exists "$FLAG"

# --- Strict opt-in → exit 2
set +e
out=$(printf '{"transcript_path":"%s"}\n' "$tx" | CLAUDE_PR_STATUSLINE_STRICT=1 bash "$STOP" 2>&1)
rc=$?
set -e
assert_equal "$rc" "2" "strict mode → exit 2"
assert_contains "$out" "MUST" "strict mode demands action"

# --- TTL: backdate the flag past TTL → auto-cleared + silent
# Use a short TTL for the test.
echo "https://example.com/pr/old" > "$FLAG"
touch -d "3 hours ago" "$FLAG"
set +e
out=$(printf '{"transcript_path":"%s"}\n' "$tx" | CLAUDE_PR_STATUSLINE_FLAG_TTL=3600 bash "$STOP" 2>&1)
rc=$?
set -e
assert_equal "$rc" "0" "stale flag → exit 0"
assert_equal "$out" "" "stale flag → no output"
assert_file_missing "$FLAG"

echo "stop hook modes ok"
