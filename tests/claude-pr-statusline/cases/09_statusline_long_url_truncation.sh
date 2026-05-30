#!/bin/bash
# Long PR URLs replaced with #<num> when line would overflow the terminal width.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session trunc)
sk=$(session_key_of "$tx")

cat > "$STATE_DIR/$sk" <<EOF
$REPO	feat-1	https://very.long.host.example.internal/some/org/some-repo/pull/12345	develop	12345	100
EOF

(cd "$REPO" && git checkout -q -b feat-1)
# Force narrow terminal
out=$(COLUMNS=40 statusline_input "$REPO" "$tx" | COLUMNS=40 bash "$SL" | strip_ansi)
assert_contains "$out" "#12345" "URL replaced with #num when narrow"
assert_not_contains "$out" "very.long.host" "long URL truncated away"

# Wide terminal keeps the URL
out=$(COLUMNS=200 statusline_input "$REPO" "$tx" | COLUMNS=200 bash "$SL" | strip_ansi)
assert_contains "$out" "very.long.host" "wide terminal keeps full URL"

echo "url truncation ok"
