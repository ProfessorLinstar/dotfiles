#!/bin/bash
# Snapshot-based check on the *exact* rendered output for a known stack,
# including ANSI. Catches palette / layout regressions that grep-style
# assertions miss.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session snap)
sk=$(session_key_of "$tx")

# A 2-PR stack with a child of the first.
cat > "$STATE_DIR/$sk" <<EOF
$REPO	feat-a	https://ex.com/pr/1	develop	1	100
$REPO	feat-b	https://ex.com/pr/2	feat-a	2	100
EOF

(cd "$REPO" && git checkout -q -b feat-b)

# Normalize the absolute REPO path so the snapshot is portable across runs.
raw=$(statusline_input "$REPO" "$tx" | bash "$SL")
normalized=$(printf '%s' "$raw" | sed "s|$REPO|<REPO>|g" | strip_ansi)
echo "$normalized" > "$SBX/render.txt"

diff_snapshot "$SBX/render.txt" "fixtures/statusline/two-pr-stack.expected"

echo "snapshot ok"
