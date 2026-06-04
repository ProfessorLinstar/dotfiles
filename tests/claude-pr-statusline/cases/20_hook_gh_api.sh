#!/bin/bash
# post-push-ci.sh `gh api -X POST .../pulls -f head=X` parser path.
# Exercises extract_gh_api_pulls in the embedded python.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-api --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/77\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-api\",\"number\":77,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session api)
sk=$(session_key_of "$tx")

# -X POST  +  /pulls path  +  -f head=...
hook_input_bash "gh api -X POST /repos/o/r/pulls -f head=feat-api -f base=develop -f title=t" "$REPO" "$tx" | bash "$HOOK"
assert_file_exists "$STATE_DIR/$sk"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" $'\tfeat-api\t' "gh api POST .../pulls captured"

# Should NOT match a PATCH request to /pulls (not a create)
rm -f "$STATE_DIR/$sk"
hook_input_bash "gh api -X PATCH /repos/o/r/pulls/100 -f base=develop" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

# Should NOT match a POST to a non-/pulls endpoint
rm -f "$STATE_DIR/$sk"
hook_input_bash "gh api -X POST /repos/o/r/issues -f title=t" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

echo "gh api parser ok"
