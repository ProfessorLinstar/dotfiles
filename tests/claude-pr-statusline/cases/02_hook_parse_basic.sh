#!/bin/bash
# post-push-ci.sh basic parsing paths: `gh pr create -H X`, `--head X`,
# MCP create_pull_request, and the fallback-to-current-branch case.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"

# Arm gh with a single PR.
cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-x --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://github.com/o/r/pull/100\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-x\",\"number\":100,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session basic)
sk=$(session_key_of "$tx")

# --- gh pr create -H feat-x
hook_input_bash "gh pr create -H feat-x" "$REPO" "$tx" | bash "$HOOK"
assert_file_exists "$STATE_DIR/$sk"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" "$REPO" "repo_root"
assert_contains "$row" $'\tfeat-x\t' "branch field"
assert_contains "$row" "https://github.com/o/r/pull/100" "pr_url"
assert_contains "$row" $'\tdevelop\t' "base_branch"
assert_contains "$row" $'\t100\t' "number"
assert_file_exists "$CI_DIR/push-pending-$sk"
assert_file_contents "$CI_DIR/push-pending-$sk" "https://github.com/o/r/pull/100"

# --- gh pr create --head feat-x (long form)
rm "$STATE_DIR/$sk"
hook_input_bash "gh pr create --head feat-x" "$REPO" "$tx" | bash "$HOOK"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" $'\tfeat-x\t' "long --head form"

# --- MCP create_pull_request
rm "$STATE_DIR/$sk"
hook_input_mcp_create "feat-x" "$REPO" "$tx" | bash "$HOOK"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" $'\tfeat-x\t' "mcp create"
assert_contains "$row" "https://github.com/o/r/pull/100" "mcp pr_url"

# --- git push falls back to current branch
rm -f "$STATE_DIR/$sk"
# create a branch named feat-x in the test repo so the fallback finds it
(cd "$REPO" && git checkout -q -b feat-x)
hook_input_bash "git push" "$REPO" "$tx" | bash "$HOOK"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" $'\tfeat-x\t' "git push fallback to current branch"

# --- Non-`is_push` tool calls produce no state
rm -f "$STATE_DIR/$sk" "$CI_DIR/push-pending-$sk"
hook_input_bash "ls /tmp" "$REPO" "$tx" | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

# --- Dedup: same (repo, branch) replaces, doesn't duplicate
hook_input_bash "gh pr create -H feat-x" "$REPO" "$tx" | bash "$HOOK"
hook_input_bash "gh pr create -H feat-x" "$REPO" "$tx" | bash "$HOOK"
line_count=$(wc -l < "$STATE_DIR/$sk")
assert_equal "$line_count" "1" "dedup on (repo, branch)"

echo "all hook-basic checks ok"
