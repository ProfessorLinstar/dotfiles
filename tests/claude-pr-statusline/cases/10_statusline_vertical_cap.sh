#!/bin/bash
# When tracked PRs exceed MAX_ROWS, render top (MAX_ROWS-1) and a "+N more"
# line. The current row must always be visible — even if it would be hidden.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session cap)
sk=$(session_key_of "$tx")

# 15 unrelated PRs (no stacking)
{
  for i in $(seq 1 15); do
    printf '%s\tfeat-%d\thttps://example.com/pr/%d\tdevelop\t%d\t100\n' "$REPO" "$i" "$i" "$i"
  done
} > "$STATE_DIR/$sk"

(cd "$REPO" && git checkout -q -b feat-12)

# Default cap is 10
out=$(CLAUDE_STATUSLINE_MAX_ROWS=10 statusline_input "$REPO" "$tx" | CLAUDE_STATUSLINE_MAX_ROWS=10 bash "$SL" | strip_ansi)

# feat-12 (current) must appear
assert_contains "$out" "feat-12" "current row preserved"
# "+N more" line shows remaining count
assert_contains "$out" "more" "+N more line present"
# Should not exceed cap rows + ctx line
line_count=$(printf '%s\n' "$out" | wc -l)
[ "$line_count" -le 12 ] || _fail "too many lines: $line_count"

# Smaller cap
out=$(CLAUDE_STATUSLINE_MAX_ROWS=3 statusline_input "$REPO" "$tx" | CLAUDE_STATUSLINE_MAX_ROWS=3 bash "$SL" | strip_ansi)
assert_contains "$out" "feat-12" "current row preserved at small cap"

echo "vertical cap ok"
