#!/bin/bash
# When transcript_path is absent, both hook and statusline derive the
# session_key from session_id instead. State files use the same key.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-sid --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/55\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-sid\",\"number\":55,\"state\":\"OPEN\"}"
}
JSON

session_id="abc-123-fake-session"
sk=$(md5 "$session_id")

# Hook: no transcript_path, only session_id
echo '{"tool_name":"Bash","tool_input":{"command":"gh pr create -H feat-sid"},"cwd":"'"$REPO"'","session_id":"'"$session_id"'","tool_response":{"success":true}}' \
  | bash "$HOOK"
assert_file_exists "$STATE_DIR/$sk"
assert_contains "$(cat "$STATE_DIR/$sk")" "feat-sid" "row written under session_id key"

# Statusline: same session_id, no transcript_path → renders the same row
(cd "$REPO" && git checkout -q -b feat-sid)
out=$(echo '{"workspace":{"current_dir":"'"$REPO"'"},"context_window":{"used_percentage":42},"session_id":"'"$session_id"'"}' \
  | bash "$SL" | strip_ansi)
assert_contains "$out" "feat-sid" "statusline renders under session_id"

echo "session_id fallback ok"
