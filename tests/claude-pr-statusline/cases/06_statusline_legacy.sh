#!/bin/bash
# Statusline legacy fallback: no session state file → single-line view.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"

tx=$(mk_session legacy)
(cd "$REPO" && git checkout -q -b feat-x)

# No PR cached, no gh fixture → renders without PR
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)
assert_contains "$out" "feat-x" "current branch shown"
assert_contains "$out" "42%" "context pct shown"

# Cache pre-populated with a PR URL → URL appears
mkdir -p "$HOME/.local/state/claude/pr-cache"
repo_key=$(md5 "$REPO")
echo "https://example.com/pr/1" > "$HOME/.local/state/claude/pr-cache/${repo_key}_feat-x"
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)
assert_contains "$out" "https://example.com/pr/1" "cached PR shown"

echo "legacy view ok"
