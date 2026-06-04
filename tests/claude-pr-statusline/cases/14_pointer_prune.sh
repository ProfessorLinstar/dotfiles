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

# The statusline's opportunistic prune normally fires ~1/20 renders via
# $RANDOM. Use CLAUDE_STATUSLINE_FORCE_PRUNE=1 for deterministic test runs.
echo "ghost-also" > "$STATE_DIR/_by_workspace/eee"
tx=$(mk_session prune)
CLAUDE_STATUSLINE_FORCE_PRUNE=1 statusline_input "$REPO" "$tx" \
  | CLAUDE_STATUSLINE_FORCE_PRUNE=1 bash "$SL" > /dev/null
# Legacy single-file dangling pointer (no state file for "ghost-also") → dropped
assert_file_missing "$STATE_DIR/_by_workspace/eee"
# Statusline also drops malformed pointers (legacy file format)
[ ! -f "$STATE_DIR/_by_workspace/ccc" ] || _fail "malformed pointer ccc not dropped"
[ ! -f "$STATE_DIR/_by_workspace/ddd" ] || _fail "empty pointer ddd not dropped"

# --- New layout: stale marker (no state file, mtime > grace) gets pruned
mkdir -p "$STATE_DIR/_by_workspace/wsX"
touch "$STATE_DIR/_by_workspace/wsX/stale-session"
touch -d "1 hour ago" "$STATE_DIR/_by_workspace/wsX/stale-session"
CLAUDE_STATUSLINE_FORCE_PRUNE=1 CLAUDE_STATUSLINE_MARKER_GRACE=300 \
  statusline_input "$REPO" "$tx" \
  | CLAUDE_STATUSLINE_FORCE_PRUNE=1 CLAUDE_STATUSLINE_MARKER_GRACE=300 bash "$SL" > /dev/null
[ ! -f "$STATE_DIR/_by_workspace/wsX/stale-session" ] || _fail "stale marker not pruned"

# --- New layout: fresh marker (no state file, mtime < grace) is kept
mkdir -p "$STATE_DIR/_by_workspace/wsY"
touch "$STATE_DIR/_by_workspace/wsY/fresh-session"
CLAUDE_STATUSLINE_FORCE_PRUNE=1 CLAUDE_STATUSLINE_MARKER_GRACE=300 \
  statusline_input "$REPO" "$tx" \
  | CLAUDE_STATUSLINE_FORCE_PRUNE=1 CLAUDE_STATUSLINE_MARKER_GRACE=300 bash "$SL" > /dev/null
[ -f "$STATE_DIR/_by_workspace/wsY/fresh-session" ] || _fail "fresh marker incorrectly pruned"

echo "pointer prune ok"
