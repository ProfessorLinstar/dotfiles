#!/bin/bash
# Auto-seed: when no state file exists but the current branch has an open
# PR (visible via gh pr view), the legacy fallback promotes itself into
# the multi-line view by writing a row to the state file. Disable with
# CLAUDE_PR_STATUSLINE_AUTOSEED=0.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-seed --json url -q .url": "https://example.com/pr/777",
  "pr view feat-seed --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/777\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-seed\",\"number\":777,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session seed)
sk=$(session_key_of "$tx")
(cd "$REPO" && git checkout -q -b feat-seed)

# First render: legacy fallback writes URL to pr-cache AND seeds the state file
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)
assert_contains "$out" "https://example.com/pr/777" "fallback rendered URL"
assert_file_exists "$STATE_DIR/$sk"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" $'\tfeat-seed\t' "auto-seed row written"
assert_contains "$row" "https://example.com/pr/777" "auto-seed URL recorded"

# Second render: now uses multi-line view (▶ marker)
out2=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)
assert_contains "$out2" "▶" "second render promoted to multi-line"
assert_contains "$out2" "feat-seed" "feat-seed visible"

# --- Opt-out: CLAUDE_PR_STATUSLINE_AUTOSEED=0 keeps the state file empty
mk_sandbox  # fresh sandbox
cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-noseed --json url -q .url": "https://example.com/pr/888",
  "pr view feat-noseed --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/888\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-noseed\",\"number\":888,\"state\":\"OPEN\"}"
}
JSON
tx2=$(mk_session noseed)
sk2=$(session_key_of "$tx2")
(cd "$REPO" && git checkout -q -b feat-noseed)
CLAUDE_PR_STATUSLINE_AUTOSEED=0 statusline_input "$REPO" "$tx2" \
  | CLAUDE_PR_STATUSLINE_AUTOSEED=0 bash "$SL" > /dev/null
assert_file_missing "$STATE_DIR/$sk2"

echo "auto-seed ok"
