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

. "$(dirname "$0")/_lib.sh"

input=$(cat)

# Single jq pass: all needed fields in one fork. `success` is encoded as
# the literal string "false" when present and false, else "true" (`//` would
# treat boolean false as absent).
IFS=$'\t' read -r tool_name tool_success transcript cwd mcp_head <<< "$(
  echo "$input" | jq -r \
    '[.tool_name // "",
      (if .tool_response.success == false then "false" else "true" end),
      .transcript_path // .session_id // "",
      .cwd // "",
      .tool_input.head // ""] | @tsv'
)"

[ "$tool_success" = "false" ] && exit 0
[ -z "$transcript" ] && exit 0
[ -z "$cwd" ] && exit 0
session_key=$(md5 "$transcript")

# Pairs emitted by the parser as `<repo_override_or_empty>\t<head_or_empty>`.
# Empty head means "use the cwd's current branch" (covers plain `git push`
# and `gh pr create` with no explicit head).
pairs=""
if [ "$tool_name" = "mcp__github__create_pull_request" ]; then
  [ -z "$mcp_head" ] && exit 0
  # Prefer the PR data carried in tool_response. The MCP server just
  # returned it; using it here avoids the propagation race where
  # `gh pr view <head>` against GitHub's API can return empty for a
  # brand-new PR. Field names span two shapes: REST API
  # (html_url, head.ref, base.ref, state=lowercase) and gh's --json
  # (url, headRefName, baseRefName, state=uppercase). Try both.
  IFS=$'\t' read -r mcp_url mcp_number mcp_state mcp_head_resp mcp_base <<< "$(
    echo "$input" | jq -r '
      (.tool_response // {}) as $r |
      [ ($r.html_url // $r.url // ""),
        (($r.number // "") | tostring),
        (($r.state // "") | ascii_upcase),
        ($r.head.ref // $r.headRefName // ""),
        ($r.base.ref // $r.baseRefName // "") ] | @tsv'
  )"
  mcp_base="${mcp_base%-cached}"
  [ -z "$mcp_head_resp" ] && mcp_head_resp="$mcp_head"

  if [ -n "$mcp_url" ] && [ -n "$mcp_head_resp" ] && [ -n "$mcp_base" ] \
     && [ -n "$mcp_number" ] && pr_is_alive "$mcp_state"; then
    # Full PR data from tool_response — bypass `gh pr view` entirely.
    state_ensure_dirs
    repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    [ -z "$repo_root" ] && repo_root="$cwd"
    upsert_pr_state "$session_key" "$repo_root" "$mcp_head_resp" "$mcp_url" "$mcp_base" "$mcp_number"
    exit 0
  fi
  # tool_response incomplete → fall back to `gh pr view`. Logged so
  # silent regressions in the MCP server's response shape surface in
  # the debug log instead of just being a perf hit.
  dbg "mcp fast-path incomplete: url='$mcp_url' head='$mcp_head_resp' base='$mcp_base' num='$mcp_number' state='$mcp_state' — falling back to gh pr view"
  pairs=$(printf '\t%s\n' "$mcp_head")
elif [ "$tool_name" = "Bash" ]; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
  [ -z "$cmd" ] && exit 0
  pairs=$(CMD="$cmd" python3 <<'PY'
import re, shlex, os, sys

cmd = os.environ.get('CMD', '')
# shlex doesn't isolate single-char operators ';' '|' from neighbouring
# tokens — `a; b` tokenizes as `['a;', 'b']`. Pre-space them so they
# come out as their own tokens. Also strip stray `( ... )` subshell
# wrappers, which would attach to `cd` / `feat` and break detection.
cmd = re.sub(r'(?<![&|])([;|&])(?![|&])', r' \1 ', cmd)  # avoid breaking `&&`/`||`
cmd = re.sub(r'[()]', ' ', cmd)
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

# Bash allows inline env-var assignments before a command:
#   GH_HOST=foo gh pr create -H feat
#   A=1 B=2 git push
# shlex emits each KEY=VALUE as its own token. Strip them so the dispatch
# below sees `gh`/`git` as sub[0].
ENV_ASSIGN_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')

def strip_env_prefix(sub):
    i = 0
    while i < len(sub) and ENV_ASSIGN_RE.match(sub[i]):
        i += 1
    return sub[i:]

cd_override = None
out = []
for sub in subs:
    if not sub:
        continue
    sub = strip_env_prefix(sub)
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
  pr_is_alive "$PR_STATE" || continue

  upsert_pr_state "$session_key" "$repo_root" "$PR_HEAD" "$PR_URL" "$PR_BASE" "$PR_NUMBER"
done <<< "$pairs"

exit 0
