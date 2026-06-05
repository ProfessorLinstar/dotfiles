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

. "$(dirname "$0")/_lib.sh"
state_ensure_dirs

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
  state-dir) printf '%s\n' "$STATE_DIR" ;;
  ci-dir)    printf '%s\n' "$CI_DIR" ;;
  state-file)
    # Returns the path of THIS workspace's session state file. The file may
    # not exist yet — callers writing for the first time will create it.
    target="$WORKSPACE_DIR/$(md5 "$PWD")"
    if [ -d "$target" ]; then
      # Modern layout: directory of touched markers. ls -t picks the most
      # recent statusline render in this PWD.
      newest=$(ls -t "$target" 2>/dev/null | head -1)
      if guard_basename "$newest"; then
        printf '%s\n' "$STATE_DIR/$newest"
      fi
    elif [ -f "$target" ]; then
      session=$(cat "$target")
      if guard_basename "$session"; then
        printf '%s\n' "$STATE_DIR/$session"
      fi
    fi
    ;;
  write-rows)
    target="${2:-}"
    [ -z "$target" ] && { echo "pr-state.sh write-rows: missing <target>" >&2; exit 1; }
    guard_state_path "$target"
    atomic_write "$target"
    ;;
  clear-flag)
    key="${2:-}"
    [ -z "$key" ] && { echo "pr-state.sh clear-flag: missing <session_key>" >&2; exit 1; }
    guard_basename "$key" || { echo "pr-state.sh clear-flag: invalid key: $key" >&2; exit 1; }
    rm -f "$CI_DIR/push-pending-$key"
    ;;
  drop-state)
    target="${2:-}"
    [ -z "$target" ] && { echo "pr-state.sh drop-state: missing <target>" >&2; exit 1; }
    guard_state_path "$target"
    rm -f "$target"
    ;;
  prune-pointers)
    shopt -s nullglob
    for entry in "$WORKSPACE_DIR"/*; do
      if [ -d "$entry" ]; then
        for marker in "$entry"/*; do
          [ -f "$marker" ] || continue
          mname=$(basename "$marker")
          if guard_basename "$mname" && [ -f "$STATE_DIR/$mname" ]; then
            continue
          fi
          rm -f "$marker"
        done
        rmdir "$entry" 2>/dev/null || true
      elif [ -f "$entry" ]; then
        sk=$(cat "$entry" 2>/dev/null || true)
        if guard_basename "$sk" && [ -f "$STATE_DIR/$sk" ]; then
          continue
        fi
        rm -f "$entry"
      fi
    done
    shopt -u nullglob
    ;;
  *)
    echo "usage: $0 {state-dir|ci-dir|state-file|write-rows <target>|clear-flag <key>|drop-state <target>|prune-pointers}" >&2
    exit 1
    ;;
esac
