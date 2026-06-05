#!/bin/bash
# Append-only PR log: hook writes every observed PR to pr-log/<session_key>;
# refresh-core uses it as a seed source.

set -e
source "$TEST_ROOT/lib/setup.sh"
test_init log

gh_fixture_pr     feat-1                       OPEN develop 1
gh_fixture_pr     feat-2                       OPEN feat-1  2
gh_fixture_pr_url https://example.com/pr/1     OPEN develop feat-1 1
gh_fixture_pr_url https://example.com/pr/2     OPEN feat-1  feat-2 2

# Create two PRs via the hook
hook_input_bash "gh pr create -H feat-1" "$REPO" "$TX" | bash "$HOOK"
hook_input_bash "gh pr create -H feat-2" "$REPO" "$TX" | bash "$HOOK"

# Log captured both
assert_file_exists "$LOG_DIR/$SK"
assert_equal "$(wc -l < "$LOG_DIR/$SK")" "2" "PR log captured both creates"
assert_contains "$(cat "$LOG_DIR/$SK")" "https://example.com/pr/1" "pr/1 in log"
assert_contains "$(cat "$LOG_DIR/$SK")" "https://example.com/pr/2" "pr/2 in log"

# Simulate conversation compaction: wipe the state file, leaving only the log.
rm "$STATE_DIR/$SK"

# Refresh with NO stdin (post-compaction Claude has no context to feed it).
printf '' | bash "$REFRESH" "$STATE_DIR/$SK" > /dev/null
assert_equal "$(wc -l < "$STATE_DIR/$SK")" "2" "refresh-core recovers both PRs from log"
assert_contains "$(cat "$STATE_DIR/$SK")" "feat-1" "pr/1 row reconstructed"
assert_contains "$(cat "$STATE_DIR/$SK")" "feat-2" "pr/2 row reconstructed"

# Log dedup: hook re-fires for feat-1 (another push). Log grows; refresh dedups by URL.
hook_input_bash "git push" "$REPO" "$TX" | (cd "$REPO" && git checkout -q -b feat-1 && cat | bash "$HOOK")
assert_equal "$(wc -l < "$LOG_DIR/$SK")" "3" "log appended on re-push"

printf '' | bash "$REFRESH" "$STATE_DIR/$SK" > /dev/null
assert_equal "$(wc -l < "$STATE_DIR/$SK")" "2" "refresh-core dedups across log entries"

echo "PR log ok"
