#!/bin/bash
# Mutation helper for the per-session PR tracking state used by the
# Claude statusline. Slash commands call this so they only need a single
# blanket Bash permission rather than per-pattern rm/echo/mv allows.
#
# State lives under ~/.local/state/claude/ so it persists across /tmp
# wipes (container restarts, reboots) and survives `claude --resume`.
#
# Usage:
#   pr-state.sh state-file           Print path of the current workspace's
#                                    session state file (may not exist yet
#                                    — caller writes to it). Empty output
#                                    if no _by_workspace pointer is set
#                                    (statusline hasn't rendered here yet).
#   pr-state.sh state-dir            Print the state directory.
#   pr-state.sh ci-dir               Print the ci-state (push-pending) dir.
#   pr-state.sh write-rows <target>  Read TSV from stdin, atomically replace
#                                    <target> (must live under state-dir).
#   pr-state.sh clear-flag <key>     Remove push-pending-<key> flag.
#   pr-state.sh drop-state <target>  Remove a session state file.
#   pr-state.sh prune-pointers       Drop _by_workspace pointers whose
#                                    target session file no longer exists.

set -e

STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"
mkdir -p "$STATE_DIR" "$STATE_DIR/_by_workspace" "$CI_DIR"

guard_state_path() {
  case "$1" in
    "$STATE_DIR"/*) : ;;
    *) echo "pr-state.sh: refusing to touch path outside $STATE_DIR: $1" >&2; exit 1 ;;
  esac
}

case "$1" in
  state-dir)
    printf '%s\n' "$STATE_DIR"
    ;;
  ci-dir)
    printf '%s\n' "$CI_DIR"
    ;;
  state-file)
    # Returns the path of THIS workspace's session state file. The file may
    # not exist yet — callers writing for the first time will create it.
    # Never falls back to another session's file: cross-session writes
    # silently corrupt data, so refuse rather than guess.
    ws=$(echo -n "$PWD" | md5sum | cut -d' ' -f1)
    pointer="$STATE_DIR/_by_workspace/$ws"
    if [ -f "$pointer" ]; then
      session=$(cat "$pointer")
      case "$session" in
        */*|*..*|"") ;;  # malformed pointer, ignore
        *) printf '%s\n' "$STATE_DIR/$session" ;;
      esac
    fi
    # No pointer → empty output. Caller should ensure the statusline has
    # rendered at least once for this workspace (which writes the pointer).
    ;;
  write-rows)
    target="$2"
    [ -z "$target" ] && { echo "pr-state.sh write-rows: missing <target>" >&2; exit 1; }
    guard_state_path "$target"
    tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX")
    cat > "$tmp"
    mv "$tmp" "$target"
    ;;
  clear-flag)
    key="$2"
    [ -z "$key" ] && { echo "pr-state.sh clear-flag: missing <session_key>" >&2; exit 1; }
    case "$key" in
      */*|*..*) echo "pr-state.sh clear-flag: invalid key: $key" >&2; exit 1 ;;
    esac
    rm -f "$CI_DIR/push-pending-$key"
    ;;
  drop-state)
    target="$2"
    [ -z "$target" ] && { echo "pr-state.sh drop-state: missing <target>" >&2; exit 1; }
    guard_state_path "$target"
    rm -f "$target"
    ;;
  prune-pointers)
    for ptr in "$STATE_DIR/_by_workspace"/*; do
      [ -f "$ptr" ] || continue
      sk=$(cat "$ptr")
      [ -f "$STATE_DIR/$sk" ] || rm -f "$ptr"
    done
    ;;
  *)
    echo "usage: $0 {state-dir|ci-dir|state-file|write-rows <target>|clear-flag <key>|drop-state <target>|prune-pointers}" >&2
    exit 1
    ;;
esac
