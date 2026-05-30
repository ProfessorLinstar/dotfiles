#!/bin/bash
# Detached HEAD: cur_branch resolves to a short SHA; statusline still renders.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
tx=$(mk_session det)

(cd "$REPO" && git -c commit.gpgsign=false commit -q --allow-empty -m two && git checkout -q --detach HEAD)
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)

# Should not be empty, should contain short SHA-ish thing (7 hex chars)
assert_contains "$out" "42%" "rendered with ctx"
# Allow either a short SHA or "no branch"
if ! printf '%s' "$out" | grep -qE '[0-9a-f]{7}|no branch'; then
  _fail "expected short SHA or 'no branch' marker"
fi

echo "detached head ok"
