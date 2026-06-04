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
#                                    if no _by_workspace marker exists yet.
#                                    Modern layout: _by_workspace/<md5(PWD)>
#                                    is a DIRECTORY of `touch`ed markers,
#                                    one per session. `ls -t` picks the
#                                    most-recently-touched session — the
#                                    one whose statusline just rendered
#                                    here. Legacy: <md5(PWD)> as a single
#                                    file is still recognized.
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
  # Reject `..` segments anywhere in the path before they can escape via the
  # prefix match (e.g. "$STATE_DIR/../etc/foo" passes a naive prefix check).
  case "$1" in
    *..*) echo "pr-state.sh: refusing path containing '..': $1" >&2; exit 1 ;;
  esac
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
    # Never falls back to a session whose state file is missing — bail
    # rather than silently corrupt.
    ws=$(echo -n "$PWD" | md5sum | cut -d' ' -f1)
    target="$STATE_DIR/_by_workspace/$ws"
    if [ -d "$target" ]; then
      # Modern layout: directory of touched markers. `ls -t` returns names
      # newest-first; the most-recent statusline render in this PWD wins.
      # The state file itself may not exist yet — the marker is the proof
      # of session presence; the caller may be about to write the file.
      newest=$(ls -t "$target" 2>/dev/null | head -1)
      case "$newest" in
        */*|*..*|"") ;;
        *) printf '%s\n' "$STATE_DIR/$newest" ;;
      esac
    elif [ -f "$target" ]; then
      # Legacy single-file pointer.
      session=$(cat "$target")
      case "$session" in
        */*|*..*|"") ;;
        *) printf '%s\n' "$STATE_DIR/$session" ;;
      esac
    fi
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
    shopt -s nullglob
    for entry in "$STATE_DIR/_by_workspace"/*; do
      if [ -d "$entry" ]; then
        # Modern: directory of session markers. Drop markers whose target
        # session file is gone; rmdir the workspace dir if it ends up empty.
        for marker in "$entry"/*; do
          [ -f "$marker" ] || continue
          mname=$(basename "$marker")
          case "$mname" in
            */*|*..*|"") rm -f "$marker" ;;
            *) [ -f "$STATE_DIR/$mname" ] || rm -f "$marker" ;;
          esac
        done
        rmdir "$entry" 2>/dev/null || true
      elif [ -f "$entry" ]; then
        # Legacy single-file pointer.
        sk=$(cat "$entry" 2>/dev/null || true)
        case "$sk" in
          */*|*..*|"") rm -f "$entry" ;;
          *) [ -f "$STATE_DIR/$sk" ] || rm -f "$entry" ;;
        esac
      fi
    done
    shopt -u nullglob
    ;;
  *)
    echo "usage: $0 {state-dir|ci-dir|state-file|write-rows <target>|clear-flag <key>|drop-state <target>|prune-pointers}" >&2
    exit 1
    ;;
esac
