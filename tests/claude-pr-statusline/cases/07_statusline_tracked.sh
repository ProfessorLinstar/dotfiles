#!/bin/bash
# Statusline with a tracked stack: depth-based ordering, current row marked.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session tracked)
sk=$(session_key_of "$tx")

# 3-PR stack in REPO: feat-1 → feat-2 → feat-3
# Write rows in random order; depth sort should put feat-1 first.
cat > "$STATE_DIR/$sk" <<EOF
$REPO	feat-3	https://example.com/pr/3	feat-2	3	100
$REPO	feat-1	https://example.com/pr/1	develop	1	100
$REPO	feat-2	https://example.com/pr/2	feat-1	2	100
EOF

(cd "$REPO" && git checkout -q -b feat-2)
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)

# Order: feat-1, feat-2, feat-3 (top down)
lines=$(printf '%s\n' "$out" | grep -E '(feat-)')
first=$(printf '%s\n' "$lines" | sed -n '1p')
second=$(printf '%s\n' "$lines" | sed -n '2p')
third=$(printf '%s\n' "$lines" | sed -n '3p')
assert_contains "$first" "feat-1" "first row is feat-1"
assert_contains "$second" "feat-2" "second row is feat-2"
assert_contains "$third" "feat-3" "third row is feat-3"

# Current marker on feat-2
assert_contains "$second" "▶" "feat-2 marked as current"
assert_not_contains "$first" "▶" "feat-1 not marked"
assert_not_contains "$third" "▶" "feat-3 not marked"

echo "stack sort ok"
