#!/bin/bash
# cleanup-pr-state-core: walks every pr-state/* file, drops merged/closed,
# deletes empty files, prunes pointers.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

CORE="$SCRIPTS_ROOT/cleanup-pr-state-core.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR/_by_workspace"

# Two session files, each with a mix of states.
cat > "$STATE_DIR/sess-a" <<EOF
$REPO	keep-1	https://example.com/pr/1	develop	1	100
$REPO	merged-1	https://example.com/pr/2	develop	2	100
$REPO	closed-1	https://example.com/pr/3	develop	3	100
EOF

cat > "$STATE_DIR/sess-b" <<EOF
$REPO	gone-1	https://example.com/pr/9	develop	9	100
EOF

# Pointer to sess-a (will remain), pointer to sess-b (will become dangling
# once sess-b's only row is dropped and the file is deleted).
ws_a=$(md5 "/some/workspace-a")
ws_b=$(md5 "/some/workspace-b")
echo "sess-a" > "$STATE_DIR/_by_workspace/$ws_a"
echo "sess-b" > "$STATE_DIR/_by_workspace/$ws_b"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view https://example.com/pr/1 --json state": "{\"state\":\"OPEN\"}",
  "pr view https://example.com/pr/2 --json state": "{\"state\":\"MERGED\"}",
  "pr view https://example.com/pr/3 --json state": "{\"state\":\"CLOSED\"}"
}
JSON
# pr/9 has no fixture → "unreachable"

out=$(bash "$CORE")

# sess-a kept (with 1 row), sess-b deleted
assert_file_exists "$STATE_DIR/sess-a"
sa_line_count=$(wc -l < "$STATE_DIR/sess-a")
assert_equal "$sa_line_count" "1" "sess-a has 1 row after cleanup"
assert_contains "$(cat "$STATE_DIR/sess-a")" "keep-1" "OPEN row kept"
assert_not_contains "$(cat "$STATE_DIR/sess-a")" "merged-1" "MERGED dropped"
assert_not_contains "$(cat "$STATE_DIR/sess-a")" "closed-1" "CLOSED dropped"

assert_file_missing "$STATE_DIR/sess-b"

# Dangling pointer pruned
assert_file_exists "$STATE_DIR/_by_workspace/$ws_a"
assert_file_missing "$STATE_DIR/_by_workspace/$ws_b"

# Summary fields
assert_contains "$out" "scanned=2" "scanned count"
assert_contains "$out" "merged=1" "merged count"
assert_contains "$out" "closed=1" "closed count"
assert_contains "$out" "unreachable=1" "unreachable count"
assert_contains "$out" "files_deleted=1" "files deleted count"

echo "cleanup-pr-state-core ok"
