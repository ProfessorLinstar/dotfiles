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
# Side effects:
# 1. ci-state/push-pending-<session_key>  — Stop hook nudge flag.
# 2. pr-state/<session_key>               — TSV row per tracked PR.
# 3. pr-cache/<md5(repo)>_<branch>        — fallback PR URL cache.
# 4. pr-log/<session_key>                 — append-only observation log.

. "$(dirname "$0")/_lib.sh"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Skip when the tool itself failed. (`//` treats false as absent — check
# the type explicitly.)
if [ "$(echo "$input" | jq -r 'if .tool_response.success == false then "false" else "" end')" = "false" ]; then
  exit 0
fi

transcript=$(echo "$input" | jq -r '.transcript_path // .session_id // empty')
[ -z "$transcript" ] && exit 0
session_key=$(md5 "$transcript")

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && exit 0

# Pairs emitted by the parser as `<repo_override_or_empty>\t<head_or_empty>`.
# Empty head means "use the cwd's current branch" (covers plain `git push`
# and `gh pr create` with no explicit head).
pairs=""
if [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  mcp_head=$(echo "$input" | jq -r '.tool_input.head // empty')
  [ -z "$mcp_head" ] && exit 0
  pairs=$(printf '\t%s\n' "$mcp_head")
elif [ "$tool_name" = "Bash" ]; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
  [ -z "$cmd" ] && exit 0
  pairs=$(CMD="$cmd" python3 <<'PY'
import shlex, os, sys

cmd = os.environ.get('CMD', '')
try:
    tokens = shlex.split(cmd, posix=True, comments=False)
except ValueError:
    sys.exit(0)

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
    has_post = has_pulls = False
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
        cd_override = sub[1]
        continue
    if len(sub) >= 3 and sub[0] == 'gh' and sub[1] == 'pr' and sub[2] == 'create':
        heads = extract_gh_create(sub[3:])
        if heads:
            for h in heads:
                out.append((cd_override or '', h))
        else:
            out.append((cd_override or '', ''))
    elif len(sub) >= 2 and sub[0] == 'gh' and sub[1] == 'api':
        for h in extract_gh_api_pulls(sub[2:]):
            out.append((cd_override or '', h))
    elif len(sub) >= 2 and sub[0] == 'git' and sub[1] == 'push':
        out.append((cd_override or '', ''))

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

state_ensure_dirs
log_file="$LOG_DIR/$session_key"
state_file="$STATE_DIR/$session_key"
last_pr_url=""
last_repo_root=""
last_pr_head=""

while IFS= read -r line; do
  # Split on first TAB — read with tab IFS would strip leading tabs.
  repo_override="${line%%$'\t'*}"
  head_branch="${line#*$'\t'}"
  pair_cwd="${repo_override:-$cwd}"
  repo_root=$(git -C "$pair_cwd" rev-parse --show-toplevel 2>/dev/null)
  [ -z "$repo_root" ] && repo_root="$pair_cwd"

  if [ -z "$head_branch" ]; then
    head_branch=$(git -C "$repo_root" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    [ -z "$head_branch" ] && continue
  fi

  gh_pr_view_full "$head_branch" "$repo_root" || continue
  [ -z "$PR_URL" ] && continue
  case "$PR_STATE" in OPEN|DRAFT) ;; *) continue ;; esac

  new_row=$(emit_row "$repo_root" "$PR_HEAD" "$PR_URL" "$PR_BASE" "$PR_NUMBER")

  if [ -f "$state_file" ]; then
    awk -F'\t' -v r="$repo_root" -v b="$PR_HEAD" '$1==r && $2==b {next} {print}' "$state_file" \
      | atomic_write "$state_file"
  fi
  printf '%s\n' "$new_row" >> "$state_file"

  # Append-only PR log: durable seed source for /refresh-pr-state, survives
  # conversation compaction. TSV: ts, pr_url, repo_root, head, source.
  printf '%s\t%s\t%s\t%s\thook\n' "$(date +%s)" "$PR_URL" "$repo_root" "$PR_HEAD" >> "$log_file"

  last_pr_url="$PR_URL"
  last_repo_root="$repo_root"
  last_pr_head="$PR_HEAD"
done <<< "$pairs"

if [ -n "$last_pr_url" ]; then
  echo "$last_pr_url" > "$CI_DIR/push-pending-$session_key"
  echo "$last_pr_url" > "$CACHE_DIR/$(md5 "$last_repo_root")_${last_pr_head}"
fi

exit 0
