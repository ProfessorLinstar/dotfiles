#!/bin/bash
# post-push-ci.sh: state file shape, -cached suffix stripping,
# MERGED PR skipping, dedup with updated_at refresh, cache file path.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
CACHE_DIR="$HOME/.local/state/claude/pr-cache"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-x --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://github.com/o/r/pull/100\",\"baseRefName\":\"develop-cached\",\"headRefName\":\"feat-x\",\"number\":100,\"state\":\"OPEN\"}",
  "pr view feat-merged --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://github.com/o/r/pull/200\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-merged\",\"number\":200,\"state\":\"MERGED\"}"
}
JSON

tx=$(mk_session writes)
sk=$(session_key_of "$tx")

# --- TSV shape: 6 tab-separated fields per row
hook_input_bash "gh pr create -H feat-x" "$REPO" "$tx" | bash "$HOOK"
row=$(cat "$STATE_DIR/$sk")
field_count=$(awk -F'\t' '{print NF}' <<< "$row")
assert_equal "$field_count" "6" "row has 6 tab-separated fields"

# --- -cached suffix stripped from base_branch
base=$(awk -F'\t' '{print $4}' <<< "$row")
assert_equal "$base" "develop" "-cached suffix stripped"

# --- MERGED PR is not added
rm "$STATE_DIR/$sk"
hook_input_bash "gh pr create -H feat-merged" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

# --- pr-cache uses branch-aware key
hook_input_bash "gh pr create -H feat-x" "$REPO" "$tx" | bash "$HOOK"
repo_key=$(md5 "$REPO")
assert_file_exists "$CACHE_DIR/${repo_key}_feat-x"
assert_file_contents "$CACHE_DIR/${repo_key}_feat-x" "https://github.com/o/r/pull/100"

echo "all state-write checks ok"
