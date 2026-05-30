#!/bin/bash
# post-push-ci.sh edge parsing: `--head=value`, `-Hvalue`, quoted values,
# leading `cd /repo &&` prefix. Pins the spec for the parser rewrite.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-x --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://github.com/o/r/pull/100\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-x\",\"number\":100,\"state\":\"OPEN\"}",
  "pr view feat-y --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://github.com/o/r/pull/101\",\"baseRefName\":\"feat-x\",\"headRefName\":\"feat-y\",\"number\":101,\"state\":\"OPEN\"}",
  "pr view feat space --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://github.com/o/r/pull/102\",\"baseRefName\":\"main\",\"headRefName\":\"feat space\",\"number\":102,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session edge)
sk=$(session_key_of "$tx")

run_hook() {
  rm -f "$STATE_DIR/$sk"
  hook_input_bash "$1" "${2:-$REPO}" "$tx" | bash "$HOOK"
}

# --- --head=feat-x  (equals form, long flag)
run_hook "gh pr create --head=feat-x"
row=$(cat "$STATE_DIR/$sk" 2>/dev/null || echo "")
assert_contains "$row" $'\tfeat-x\t' "--head= form"

# --- -H=feat-x  (equals form, short flag)
run_hook "gh pr create -H=feat-x"
row=$(cat "$STATE_DIR/$sk" 2>/dev/null || echo "")
assert_contains "$row" $'\tfeat-x\t' "-H= form"

# --- -Hfeat-x  (no space)
run_hook "gh pr create -Hfeat-x"
row=$(cat "$STATE_DIR/$sk" 2>/dev/null || echo "")
assert_contains "$row" $'\tfeat-x\t' "-Hvalue (no space)"

# --- cd /other-repo && gh pr create -H feat-x  →  row uses /other-repo
OTHER="$SBX/other-repo"
mkdir -p "$OTHER"
(cd "$OTHER" && git init -q -b main && git config user.email t@t && git config user.name t && git -c commit.gpgsign=false commit -q --allow-empty -m init)
run_hook "cd $OTHER && gh pr create -H feat-x" "$REPO"
row=$(cat "$STATE_DIR/$sk" 2>/dev/null || echo "")
assert_contains "$row" "$OTHER" "cd-prefix updates repo_root"
assert_not_contains "$row" "$REPO	" "original cwd repo not used"

# --- echo "gh pr create -H foo" → no row (false positive guard)
run_hook 'echo "gh pr create -H foo"'
row=$(cat "$STATE_DIR/$sk" 2>/dev/null || echo "")
assert_equal "$row" "" "echo of a gh command must not be captured"

# --- gh pr create -H feat-x && gh pr create -H feat-y → both rows
run_hook "gh pr create -H feat-x && gh pr create -H feat-y"
line_count=$(wc -l < "$STATE_DIR/$sk")
assert_equal "$line_count" "2" "batched create captures both heads"
row=$(cat "$STATE_DIR/$sk")
assert_contains "$row" $'\tfeat-x\t' "first batched head"
assert_contains "$row" $'\tfeat-y\t' "second batched head"

# --- gh pr create fails (tool_response.success=false) → no row
rm -f "$STATE_DIR/$sk"
hook_input_bash "gh pr create -H feat-x" "$REPO" "$tx" false | bash "$HOOK"
assert_file_missing "$STATE_DIR/$sk"

echo "all hook-edge checks ok"
