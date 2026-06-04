#!/bin/bash
# Append-only PR log: hook writes every observed PR to pr-log/<session_key>;
# refresh-core uses it as a seed source so PRs survive conversation
# compaction (Claude can't recall them from context anymore).

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
REFRESH="$SCRIPTS_ROOT/refresh-pr-state-core.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
LOG_DIR="$HOME/.local/state/claude/pr-log"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-1 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/1\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-1\",\"number\":1,\"state\":\"OPEN\"}",
  "pr view feat-2 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/2\",\"baseRefName\":\"feat-1\",\"headRefName\":\"feat-2\",\"number\":2,\"state\":\"OPEN\"}",
  "pr view https://example.com/pr/1 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/1\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-1\",\"number\":1,\"state\":\"OPEN\"}",
  "pr view https://example.com/pr/2 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/2\",\"baseRefName\":\"feat-1\",\"headRefName\":\"feat-2\",\"number\":2,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session log)
sk=$(session_key_of "$tx")

# Create two PRs via the hook
hook_input_bash "gh pr create -H feat-1" "$REPO" "$tx" | bash "$HOOK"
hook_input_bash "gh pr create -H feat-2" "$REPO" "$tx" | bash "$HOOK"

# Log captured both
assert_file_exists "$LOG_DIR/$sk"
log_lines=$(wc -l < "$LOG_DIR/$sk")
assert_equal "$log_lines" "2" "PR log captured both creates"
assert_contains "$(cat "$LOG_DIR/$sk")" "https://example.com/pr/1" "pr/1 in log"
assert_contains "$(cat "$LOG_DIR/$sk")" "https://example.com/pr/2" "pr/2 in log"

# Simulate conversation compaction: wipe the state file, leaving only the log.
rm "$STATE_DIR/$sk"

# Refresh with NO stdin (post-compaction Claude has no context to feed it).
# Should still recover both PRs from the log.
printf '' | bash "$REFRESH" "$STATE_DIR/$sk" > /dev/null
line_count=$(wc -l < "$STATE_DIR/$sk")
assert_equal "$line_count" "2" "refresh-core recovers both PRs from log"
assert_contains "$(cat "$STATE_DIR/$sk")" "feat-1" "pr/1 row reconstructed"
assert_contains "$(cat "$STATE_DIR/$sk")" "feat-2" "pr/2 row reconstructed"

# Log dedup: hook re-fires for feat-1 (e.g. another push to same branch).
# Log grows; refresh-core dedups by URL.
hook_input_bash "git push" "$REPO" "$tx" | (cd "$REPO" && git checkout -q -b feat-1 && cat | bash "$HOOK")
log_lines=$(wc -l < "$LOG_DIR/$sk")
assert_equal "$log_lines" "3" "log appended on re-push"

# State still has 2 rows (no duplicates).
printf '' | bash "$REFRESH" "$STATE_DIR/$sk" > /dev/null
line_count=$(wc -l < "$STATE_DIR/$sk")
assert_equal "$line_count" "2" "refresh-core dedups across log entries"

echo "PR log ok"
