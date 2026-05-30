#!/bin/bash
# Data fields containing backslash escapes should not be interpreted as
# printf %b escape sequences. A branch literally containing a backslash
# should render as-is, not inject newlines/tabs/etc.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session escape)
sk=$(session_key_of "$tx")

# A path with literal \n in it (legal in unix). The statusline must not
# turn this into an actual newline when rendering.
weird_path="$REPO"
cat > "$STATE_DIR/$sk" <<EOF
${weird_path}	feat\nfoo	https://example.com/pr/1	develop	1	100
EOF

(cd "$REPO" && git checkout -q -b unrelated)
out=$(statusline_input "$REPO" "$tx" | bash "$SL" | strip_ansi)

# The two characters \ and n must appear literally somewhere
assert_contains "$out" 'feat\nfoo' "branch with literal backslash-n preserved"

echo "printf escape ok"
