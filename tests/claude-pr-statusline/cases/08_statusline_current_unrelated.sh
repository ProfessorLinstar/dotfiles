#!/bin/bash
# Current (repo, branch) not in tracked stack → renders below with blank-line
# separator. Should NOT have a ▶ on any tracked row.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session unrelated)
sk=$(session_key_of "$tx")

cat > "$STATE_DIR/$sk" <<EOF
$REPO	feat-1	https://example.com/pr/1	develop	1	100
EOF

(cd "$REPO" && git checkout -q -b totally-different)
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)

# Two ▶ would be a bug — only the current block gets one.
marker_count=$(printf '%s' "$out" | tr -cd '▶' | wc -c)
# Each ▶ is 3 bytes in UTF-8.
marker_count=$((marker_count / 3))
assert_equal "$marker_count" "1" "exactly one current marker"

# tracked row appears (without marker), current branch appears (with marker)
assert_contains "$out" "feat-1" "tracked row visible"
assert_contains "$out" "totally-different" "current branch visible"

# Blank line separator between stack and current block
blank_count=$(printf '%s\n' "$out" | grep -c '^$' || true)
[ "$blank_count" -ge 1 ] || _fail "expected at least one blank line separator"

echo "unrelated-current ok"
