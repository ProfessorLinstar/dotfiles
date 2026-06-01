#!/bin/bash
# Resume simulation: same transcript_path across "session restart" produces
# the same session_key → state file survives → statusline picks back up.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HOOK="$SCRIPTS_ROOT/post-push-ci.sh"
SL="$SCRIPTS_ROOT/statusline.sh"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view feat-resume --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/77\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-resume\",\"number\":77,\"state\":\"OPEN\"}"
}
JSON

tx=$(mk_session resume)
sk=$(session_key_of "$tx")
(cd "$REPO" && git checkout -q -b feat-resume)

# --- Session A: hook writes row
hook_input_bash "gh pr create -H feat-resume" "$REPO" "$tx" | bash "$HOOK"
assert_file_exists "$HOME/.local/state/claude/pr-state/$sk"
rows_before=$(cat "$HOME/.local/state/claude/pr-state/$sk")

# Snapshot state file mtime, then "kill" the session (no-op — we're testing
# that nothing else needs to happen). Simulating resume = re-running
# statusline with the same transcript_path.

out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)
assert_contains "$out" "feat-resume" "row visible after 'resume'"

rows_after=$(cat "$HOME/.local/state/claude/pr-state/$sk")
assert_equal "$rows_after" "$rows_before" "state file unchanged across resume"

# --- Workspace pointer survives a new cwd switch back to the original
ws_key=$(md5 "$REPO")
assert_file_exists "$HOME/.local/state/claude/pr-state/_by_workspace/$ws_key"
assert_file_contents "$HOME/.local/state/claude/pr-state/_by_workspace/$ws_key" "$sk"

# --- Render from a totally different cwd → pointer for THAT cwd gets written,
#     original pointer is untouched.
OTHER="$SBX/elsewhere"
mkdir -p "$OTHER"
(cd "$OTHER" && git init -q -b main && git config user.email t@t && git config user.name t && git -c commit.gpgsign=false commit -q --allow-empty -m init)
statusline_input "$OTHER" "$tx" | bash "$SL" > /dev/null
other_key=$(md5 "$OTHER")
assert_file_exists "$HOME/.local/state/claude/pr-state/_by_workspace/$other_key"
# Original still points to the same session
assert_file_contents "$HOME/.local/state/claude/pr-state/_by_workspace/$ws_key" "$sk"

echo "resume + cross-workspace pointer ok"
