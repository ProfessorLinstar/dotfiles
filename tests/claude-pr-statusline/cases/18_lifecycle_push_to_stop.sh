#!/bin/bash
# End-to-end lifecycle: gh pr create fires the hook → row written →
# statusline renders the row → push-pending Stop hook nudges → refresh-core
# clears the flag → next Stop hook is silent.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
SL="$SCRIPTS_ROOT/statusline.sh"
STOP="$SCRIPTS_ROOT/stop-ci-check.sh"
REFRESH="$SCRIPTS_ROOT/refresh-pr-state-core.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-life --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/100\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-life\",\"number\":100,\"state\":\"OPEN\"}",
  "pr view https://example.com/pr/100 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/100\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-life\",\"number\":100,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session life)
sk=$(session_key_of "$tx")
(cd "$REPO" && git checkout -q -b feat-life)

# --- Step 1: hook fires on `gh pr create`
hook_input_bash "gh pr create -H feat-life" "$REPO" "$tx" | bash "$HOOK"
assert_file_exists "$STATE_DIR/$sk"
assert_file_exists "$CI_DIR/push-pending-$sk"

# --- Step 2: statusline renders the row
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)
assert_contains "$out" "feat-life" "row rendered"
assert_contains "$out" "https://example.com/pr/100" "URL rendered"
assert_contains "$out" "▶" "current row marked"

# --- Step 3: stop hook nudges (exit 2)
set +e
nudge_out=$(printf '{"transcript_path":"%s"}\n' "$tx" | bash "$STOP" 2>&1)
nudge_rc=$?
set -e
assert_equal "$nudge_rc" "2" "stop hook blocks with exit 2"
assert_contains "$nudge_out" "babysit-ci" "nudge mentions babysit-ci"
assert_contains "$nudge_out" "https://example.com/pr/100" "nudge includes PR URL"

# --- Step 4: refresh-core clears the flag
printf '' | bash "$REFRESH" "$STATE_DIR/$sk" > /dev/null
assert_file_missing "$CI_DIR/push-pending-$sk"

# --- Step 5: next stop is silent (exit 0, no stderr nudge)
set +e
out2=$(printf '{"transcript_path":"%s"}\n' "$tx" | bash "$STOP" 2>&1)
rc2=$?
set -e
assert_equal "$rc2" "0" "stop hook silent after flag clear"
assert_equal "$out2" "" "no nudge output"

echo "lifecycle ok"
