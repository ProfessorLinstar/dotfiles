# Shared helpers for the PR-statusline scripts.
# Sourced by:
#   post-push-ci.sh, statusline.sh, pr-state.sh, stop-ci-check.sh,
#   refresh-pr-state-core.sh, discover-pr-state-core.sh, cleanup-pr-state-core.sh
#
# All functions are pure (no global writes besides the documented gh_pr_view_full
# output globals). Constants are exported so callers see them after `source`.

STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"
CACHE_DIR="$HOME/.local/state/claude/pr-cache"
LOG_DIR="$HOME/.local/state/claude/pr-log"
WORKSPACE_DIR="$STATE_DIR/_by_workspace"

# Ensure every directory the pipeline writes to exists. Cheap and idempotent.
state_ensure_dirs() {
  mkdir -p "$STATE_DIR" "$WORKSPACE_DIR" "$CI_DIR" "$CACHE_DIR" "$LOG_DIR" 2>/dev/null || true
}

# md5 of a string. Used for session_key (transcript_path) and workspace
# bucketing (md5(PWD)).
md5() {
  printf '%s' "$1" | md5sum | cut -d' ' -f1
}

# Reject session keys / workspace IDs / state-file basenames that could
# escape the state-dir via path traversal or contain slashes. Empty string
# also rejected. Caller passes a *basename*, not a full path.
guard_basename() {
  case "$1" in
    */*|*..*|"") return 1 ;;
    *) return 0 ;;
  esac
}

# Run a command (typically `gh ...`), capture stdout into $REPLY, return the
# command's exit code. Safe under `set -e` IFF called inside an `if` test
# (bash suppresses set -e for `if` conditions, including through function
# calls).
#
# Usage:
#   if gh_view_rc gh pr view "$url" --json state; then
#     # success — $REPLY holds stdout
#   else
#     # gh failed — $REPLY may be empty; caller handles
#   fi
gh_view_rc() {
  REPLY=$("$@" 2>/dev/null)
}

# Query a PR and populate globals PR_URL, PR_HEAD, PR_BASE, PR_NUMBER,
# PR_STATE. Strips `-cached` from PR_BASE. Falls back PR_HEAD to the
# input arg if the response is missing headRefName. Returns gh's exit
# code so the caller can distinguish "PR not found / closed" (0 with
# specific state) from "gh failed / network down" (non-zero).
#
# Usage:
#   gh_pr_view_full <url_or_branch> [repo_root]
#     repo_root defaults to PWD; we `cd` into it for branch-name lookups.
gh_pr_view_full() {
  local ref="$1" repo="${2:-.}"
  PR_URL= PR_HEAD= PR_BASE= PR_NUMBER= PR_STATE=
  local json rc
  if json=$(cd "$repo" 2>/dev/null && gh pr view "$ref" --json url,baseRefName,headRefName,number,state 2>/dev/null); then
    rc=0
  else
    rc=$?
  fi
  [ "$rc" -ne 0 ] && return "$rc"
  [ -z "$json" ] && return 0  # exit 0, empty stdout — caller checks PR_STATE
  IFS=$'\t' read -r PR_URL PR_BASE PR_HEAD PR_NUMBER PR_STATE < <(
    printf '%s' "$json" | jq -r '[.url, .baseRefName, .headRefName, .number, .state] | map(. // "") | @tsv'
  )
  PR_BASE="${PR_BASE%-cached}"
  [ -z "$PR_HEAD" ] && PR_HEAD="$ref"
  return 0
}

# Emit one TSV row (5 columns — updated_at dropped).
emit_row() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
}

# Atomic same-filesystem write under $STATE_DIR.
# Usage:  atomic_write <target>   # reads stdin
atomic_write() {
  local target="$1"
  local tmp
  tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX")
  cat > "$tmp"
  mv "$tmp" "$target"
}
