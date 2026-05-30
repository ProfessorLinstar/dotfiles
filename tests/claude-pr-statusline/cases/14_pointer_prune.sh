#!/bin/bash
# prune-pointers helper, plus the statusline's opportunistic prune.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

HELPER="$SCRIPTS_ROOT/pr-state.sh"
SL="$SCRIPTS_ROOT/statusline.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR/_by_workspace"

# Pointer to existing session
echo "live" > "$STATE_DIR/_by_workspace/aaa"
printf 'row\n' > "$STATE_DIR/live"

# Pointer to non-existent session
echo "ghost" > "$STATE_DIR/_by_workspace/bbb"

# Pointer to malformed session id (slash)
echo "../escape" > "$STATE_DIR/_by_workspace/ccc"

# Pointer to malformed (empty)
: > "$STATE_DIR/_by_workspace/ddd"

bash "$HELPER" prune-pointers

assert_file_exists "$STATE_DIR/_by_workspace/aaa"
assert_file_missing "$STATE_DIR/_by_workspace/bbb"
# prune-pointers in helper only removes pointers whose target session file
# doesn't exist — it doesn't yet drop malformed pointers. The statusline
# DOES drop them. Test the helper's contract first.
# (Add a stronger helper guard or rely on statusline cleanup.)

# Now the statusline's opportunistic prune. Force the RNG to hit by
# running many times.
echo "ghost-also" > "$STATE_DIR/_by_workspace/eee"
tx=$(mk_session prune)
for _ in $(seq 1 100); do
  statusline_input "$REPO" "$tx" | bash "$SL" > /dev/null
done
assert_file_missing "$STATE_DIR/_by_workspace/eee"
# Statusline also drops malformed pointers
[ ! -f "$STATE_DIR/_by_workspace/ccc" ] || _fail "malformed pointer ccc not dropped"
[ ! -f "$STATE_DIR/_by_workspace/ddd" ] || _fail "empty pointer ddd not dropped"

echo "pointer prune ok"
