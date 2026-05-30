#!/bin/bash
# PostToolUse hook: detect git push or PR creation and persist state.
#
# Captures (repo_override, head) pairs from the invoking command using a
# shlex-based parser. Supports `gh pr create -H X`, `--head X`, `--head=X`,
# `-HX`, `cd /other-repo && gh pr create -H X`, batched `&& gh pr create`,
# `gh api -X POST .../pulls -f head=X`, and MCP create_pull_request. Falls
# back to the current branch for plain `git push`. Refuses to track a PR
# when the tool reported failure.
#
# State lives under ~/.local/state/claude/ so it persists across /tmp
# wipes (container restarts, reboots) and survives `claude --resume`.
#
# Side effects:
# 1. Writes ~/.local/state/claude/ci-state/push-pending-<session_key> — the
#    Stop hook uses this to nudge Claude into spawning /babysit-ci and
#    running /refresh-pr-state before ending the turn.
# 2. Appends/updates rows in ~/.local/state/claude/pr-state/<session_key>
#    recording (repo_root, branch, pr_url, base_branch, number, updated_at).
#    The statusline reads this to show every PR the session is tracking.
# 3. Caches PR URL per-(repo,branch) at
#    ~/.local/state/claude/pr-cache/<md5(repo_root)>_<branch> for the
#    statusline's single-line fallback when no session state exists.

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Skip when the tool itself failed — avoids tracking PRs from `gh pr create`
# invocations that errored out (already-exists, permission denied, …).
# `//` treats `false` as absent, so check the type explicitly.
tool_success=$(echo "$input" | jq -r 'if .tool_response.success == false then "false" else "" end')
if [ "$tool_success" = "false" ]; then
  exit 0
fi

transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')
[ -z "$transcript" ] && exit 0
session_key=$(echo -n "$transcript" | md5sum | cut -d' ' -f1)

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && exit 0

# Pairs are emitted by the parser as `<repo_override_or_empty>\t<head_or_empty>`
# on stdout, one per line. An empty head means "use the cwd's current branch"
# (covers plain `git push` and `gh pr create` with no explicit head).
pairs=""
if [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  mcp_head=$(echo "$input" | jq -r '.tool_input.head // empty')
  [ -z "$mcp_head" ] && exit 0
  pairs=$(printf '\t%s\n' "$mcp_head")
elif [ "$tool_name" = "Bash" ]; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
  [ -z "$cmd" ] && exit 0
  pairs=$(python3 - "$cmd" <<'PY'
import shlex, sys

cmd = sys.argv[1]
try:
    tokens = shlex.split(cmd, posix=True, comments=False)
except ValueError:
    sys.exit(0)

# Split on top-level boolean/sequence operators. shlex preserves these as
# distinct tokens because they're surrounded by whitespace; sub-commands
# concatenated with no space (`a&&b`) are uncommon enough to ignore.
SEPS = {'&&', '||', ';', '|'}
subs, cur = [], []
for t in tokens:
    if t in SEPS:
        if cur:
            subs.append(cur); cur = []
    else:
        cur.append(t)
if cur:
    subs.append(cur)

def extract_gh_create(args):
    """Return list of head branches from `gh pr create` args."""
    heads = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ('-H', '--head') and i + 1 < len(args):
            heads.append(args[i+1]); i += 2; continue
        if a.startswith('--head='):
            heads.append(a[len('--head='):])
        elif a.startswith('-H=') and len(a) > 3:
            heads.append(a[3:])
        elif a.startswith('-H') and len(a) > 2 and a != '--head':
            heads.append(a[2:])
        i += 1
    return heads

def extract_gh_api_pulls(args):
    """Return list of `head=...` values from `gh api ... -X POST .../pulls`."""
    has_post = False
    has_pulls = False
    heads = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '-X' and i + 1 < len(args) and args[i+1].upper() == 'POST':
            has_post = True
        elif a.upper() == '-XPOST' or a == '--method=POST':
            has_post = True
        elif '/pulls' in a:
            has_pulls = True
        if a == '-f' and i + 1 < len(args):
            v = args[i+1]
            if v.startswith('head='):
                heads.append(v[5:])
            i += 2; continue
        i += 1
    return heads if (has_post and has_pulls) else []

cd_override = None
out = []
for sub in subs:
    if not sub:
        continue
    if sub[0] == 'cd' and len(sub) >= 2:
        # The cd's effect carries into subsequent sub-commands in this chain.
        cd_override = sub[1]
        continue
    if len(sub) >= 3 and sub[0] == 'gh' and sub[1] == 'pr' and sub[2] == 'create':
        heads = extract_gh_create(sub[3:])
        if heads:
            for h in heads:
                out.append((cd_override or '', h))
        else:
            # gh pr create with no -H → defaults to current branch
            out.append((cd_override or '', ''))
    elif len(sub) >= 2 and sub[0] == 'gh' and sub[1] == 'api':
        heads = extract_gh_api_pulls(sub[2:])
        for h in heads:
            out.append((cd_override or '', h))
    elif len(sub) >= 2 and sub[0] == 'git' and sub[1] == 'push':
        out.append((cd_override or '', ''))

# Dedup preserving order
seen = set()
for repo, head in out:
    key = (repo, head)
    if key in seen:
        continue
    seen.add(key)
    print(f"{repo}\t{head}")
PY
)
else
  exit 0
fi

[ -z "$pairs" ] && exit 0

STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"
CACHE_DIR="$HOME/.local/state/claude/pr-cache"
mkdir -p "$STATE_DIR" "$STATE_DIR/_by_workspace" "$CI_DIR" "$CACHE_DIR"
state_file="$STATE_DIR/$session_key"
ts=$(date +%s)
last_pr_url=""
last_repo_root=""
last_pr_head=""

while IFS= read -r line; do
  # Split on first TAB. `read` with tab-as-IFS would strip leading tabs
  # (because tab is IFS whitespace), losing the empty-repo case.
  repo_override="${line%%$'\t'*}"
  head_branch="${line#*$'\t'}"
  # Per-pair repo: cd-override (if any) else the hook's cwd.
  pair_cwd="${repo_override:-$cwd}"
  repo_root=$(git -C "$pair_cwd" rev-parse --show-toplevel 2>/dev/null)
  [ -z "$repo_root" ] && repo_root="$pair_cwd"

  # Empty head → use the current branch of repo_root.
  if [ -z "$head_branch" ]; then
    head_branch=$(git -C "$repo_root" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    [ -z "$head_branch" ] && continue
  fi

  pr_json=$(cd "$repo_root" && gh pr view "$head_branch" --json url,baseRefName,headRefName,number,state 2>/dev/null)
  [ -z "$pr_json" ] && continue

  state_=$(echo "$pr_json" | jq -r '.state // empty')
  if [ "$state_" != "OPEN" ] && [ "$state_" != "DRAFT" ]; then
    continue
  fi

  pr_url=$(echo "$pr_json" | jq -r '.url // empty')
  base_branch=$(echo "$pr_json" | jq -r '.baseRefName // empty')
  base_branch="${base_branch%-cached}"
  pr_head=$(echo "$pr_json" | jq -r '.headRefName // empty')
  number=$(echo "$pr_json" | jq -r '.number // empty')
  [ -z "$pr_url" ] && continue
  [ -z "$pr_head" ] && pr_head="$head_branch"

  new_row=$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$repo_root" "$pr_head" "$pr_url" "$base_branch" "$number" "$ts")

  if [ -f "$state_file" ]; then
    tmp=$(mktemp)
    awk -F'\t' -v r="$repo_root" -v b="$pr_head" '$1==r && $2==b {next} {print}' "$state_file" > "$tmp"
    mv "$tmp" "$state_file"
  fi
  printf '%s\n' "$new_row" >> "$state_file"

  last_pr_url="$pr_url"
  last_repo_root="$repo_root"
  last_pr_head="$pr_head"
done <<< "$pairs"

if [ -n "$last_pr_url" ]; then
  echo "$last_pr_url" > "$CI_DIR/push-pending-$session_key"
  # Branch-aware cache key so switching branches doesn't surface a stale URL.
  cache_key=$(printf '%s' "$last_repo_root" | md5sum | cut -d' ' -f1)
  echo "$last_pr_url" > "$CACHE_DIR/${cache_key}_${last_pr_head}"
fi

exit 0
