#!/bin/bash
# Per-session marker dir: two concurrent sessions in the same PWD each
# leave a marker — no collision, no overwrite. `state-file` resolves to
# whichever rendered most recently (by mtime).

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

SL="$SCRIPTS_ROOT/statusline.sh"
HELPER="$SCRIPTS_ROOT/pr-state.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"

tx_a=$(mk_session sess-a)
sk_a=$(session_key_of "$tx_a")
tx_b=$(mk_session sess-b)
sk_b=$(session_key_of "$tx_b")

# Both sessions render in the SAME workspace.
statusline_input "$REPO" "$tx_a" | bash "$SL" > /dev/null
# Ensure mtime separation
sleep 1
statusline_input "$REPO" "$tx_b" | bash "$SL" > /dev/null

ws_key=$(md5 "$REPO")
ws_dir="$STATE_DIR/_by_workspace/$ws_key"
[ -d "$ws_dir" ] || _fail "ws_dir not a directory: $ws_dir"

# Both markers exist — neither overwrote the other
assert_file_exists "$ws_dir/$sk_a"
assert_file_exists "$ws_dir/$sk_b"

# state-file picks the most-recently-touched marker (sess-b)
resolved=$(cd "$REPO" && bash "$HELPER" state-file)
assert_equal "$resolved" "$STATE_DIR/$sk_b" "state-file picks most-recent marker"

# Re-render session A → mtime updates, state-file now picks A
sleep 1
statusline_input "$REPO" "$tx_a" | bash "$SL" > /dev/null
resolved=$(cd "$REPO" && bash "$HELPER" state-file)
assert_equal "$resolved" "$STATE_DIR/$sk_a" "state-file follows most-recent renderer"

# --- Legacy compatibility: a pre-existing single-file pointer should still
#     resolve, and statusline migrates it to a marker dir on next render.
ws_key2=$(md5 "$SBX/legacy-repo")
mkdir -p "$SBX/legacy-repo"
(cd "$SBX/legacy-repo" && git init -q -b main && git config user.email t@t && git config user.name t && git -c commit.gpgsign=false commit -q --allow-empty -m init)
mkdir -p "$STATE_DIR/_by_workspace"
echo "legacy-session-key" > "$STATE_DIR/_by_workspace/$ws_key2"
# Make sure the legacy session file exists so state-file returns a path
: > "$STATE_DIR/legacy-session-key"
resolved=$(cd "$SBX/legacy-repo" && bash "$HELPER" state-file)
assert_equal "$resolved" "$STATE_DIR/legacy-session-key" "legacy pointer still resolves"

# Render in legacy workspace → migrates to marker dir
tx_c=$(mk_session legacy)
sk_c=$(session_key_of "$tx_c")
statusline_input "$SBX/legacy-repo" "$tx_c" | bash "$SL" > /dev/null
[ -d "$STATE_DIR/_by_workspace/$ws_key2" ] || _fail "legacy pointer was not migrated to dir"

echo "marker dir collision-free ok"
