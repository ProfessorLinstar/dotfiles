#!/bin/bash
# PostToolUse hook: snapshot PR descriptions that Claude writes, so later analysis can tell Claude-authored revisions
# apart from user-authored ones (GitHub attributes both to the user, since Claude uses the user's gh token).
#
# Triggers on:
#   - mcp__github__create_pull_request / mcp__github__update_pull_request (only when a body was passed)
#   - Bash commands containing `gh pr create`, `gh pr edit ... --body/--body-file/-b/-F`, or
#     `gh api ... pulls/<n> -f/-F body=...`
#
# After the tool runs, the hook re-fetches the PR body from GitHub (rather than parsing it out of the command) so the
# snapshot is byte-identical to what GitHub's userContentEdits history will show. Fetching happens in a detached
# background process so the hook never blocks the session.
#
# Output: one JSON line per snapshot appended to
#   $HOME/.local/state/claude/pr-bodies/<host>/<owner>/<repo>/<number>.jsonl
# with fields {ts, session_id, transcript_path, cwd, tool, url, sha256, body}.

SNAP_DIR="$HOME/.local/state/claude/pr-bodies"
LOG="$SNAP_DIR/.hook.log"

input=$(cat)

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
tool_success=$(printf '%s' "$input" | jq -r 'if (.tool_response | type) == "object" and .tool_response.success == false then "false" else "true" end')
[ "$tool_success" = "false" ] && exit 0

# Emit "<pr-ref>\t<cwd>" lines. pr-ref is a URL, number, or branch understood by `gh pr view`.
refs=$(INPUT="$input" python3 -I <<'PY'
import json, os, re, shlex, sys

d = json.loads(os.environ['INPUT'])
tool = d.get('tool_name', '')
ti = d.get('tool_input') or {}
tr = d.get('tool_response')
cwd = d.get('cwd', '')
out = []

def resp_text():
    if isinstance(tr, str):
        return tr
    return json.dumps(tr) if tr is not None else ''

URL_RE = re.compile(r'https?://[^"\s,\\]+/pull/[0-9]+')

if tool in ('mcp__github__create_pull_request', 'mcp__github__update_pull_request'):
    if tool == 'mcp__github__update_pull_request' and ti.get('body') is None:
        sys.exit(0)
    m = URL_RE.search(resp_text())
    if m:
        out.append((m.group(0), cwd))
    elif ti.get('owner') and ti.get('repo') and ti.get('pullNumber'):
        out.append((f"{ti['owner']}/{ti['repo']}#{ti['pullNumber']}", cwd))
elif tool == 'Bash':
    cmd = ti.get('command', '')
    if not re.search(r'\bgh\s+(pr\s+(create|edit)|api)\b', cmd):
        sys.exit(0)
    stdout = (tr or {}).get('stdout', '') if isinstance(tr, dict) else ''
    stdout_urls = URL_RE.findall(stdout)
    c = re.sub(r'(?<![&|])([;|&])(?![|&])', r' \1 ', cmd)
    c = re.sub(r'[()]', ' ', c)
    try:
        toks = shlex.split(c, posix=True)
    except ValueError:
        sys.exit(0)
    subs, cur = [], []
    for t in toks:
        if t in ('&&', '||', ';', '|'):
            if cur:
                subs.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        subs.append(cur)
    cur_cwd = cwd
    env_re = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')
    for s in subs:
        while s and (env_re.match(s[0]) or s[0] in ('export', 'command')):
            s = s[1:]
        if not s:
            continue
        if s[0] == 'cd' and len(s) > 1:
            p = os.path.expanduser(s[1])
            cur_cwd = p if os.path.isabs(p) else os.path.join(cur_cwd, p)
            continue
        if s[0] != 'gh' or len(s) < 2:
            continue
        repo_flag = None
        for i, a in enumerate(s):
            if a in ('-R', '--repo') and i + 1 < len(s):
                repo_flag = s[i + 1]
            elif a.startswith('--repo='):
                repo_flag = a.split('=', 1)[1]
        if s[1] == 'pr' and len(s) > 2 and s[2] == 'create':
            if stdout_urls:
                out.append((stdout_urls.pop(0), cur_cwd))
            else:
                out.append(('', cur_cwd))  # current branch's PR
        elif s[1] == 'pr' and len(s) > 2 and s[2] == 'edit':
            has_body = any(a in ('-b', '--body', '-F', '--body-file') or a.startswith(('--body=', '--body-file='))
                           for a in s[3:])
            if not has_body:
                continue
            target = ''
            skip = False
            for a in s[3:]:
                if skip:
                    skip = False
                    continue
                if a.startswith('-'):
                    if '=' not in a and a in (
                            '-b', '--body', '-F', '--body-file', '-t', '--title', '-B', '--base', '-R', '--repo',
                            '--add-label', '--remove-label', '--add-reviewer', '--remove-reviewer', '--add-assignee',
                            '--remove-assignee', '-m', '--milestone', '--add-project', '--remove-project'):
                        skip = True
                    continue
                target = a
                break
            if repo_flag and target and target.isdigit():
                target = f'{repo_flag}#{target}'
            out.append((target, cur_cwd))
        elif s[1] == 'api':
            joined = ' '.join(s)
            m = re.search(r'repos/([^/\s]+)/([^/\s]+)/pulls/([0-9]+)', joined)
            if m and re.search(r'(^|\s)body=', joined) and re.search(r'-X\s*PATCH|--method[= ]PATCH|-f\s|-F\s', joined):
                out.append((f'{m.group(1)}/{m.group(2)}#{m.group(3)}', cur_cwd))
            elif re.search(r'repos/[^/\s]+/[^/\s]+/pulls(\s|$)', joined) and stdout_urls:
                out.append((stdout_urls.pop(0), cur_cwd))

for ref, c in out:
    print(f'{ref}\t{c}')
PY
)
[ -z "$refs" ] && exit 0

mkdir -p "$SNAP_DIR"

# Detach: the fetch may need retries for read-replica lag after `gh pr create`.
(
  session_id=$(printf '%s' "$input" | jq -r '.session_id // ""')
  transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
  while IFS=$'\t' read -r ref ref_cwd; do
    view_args=()
    case "$ref" in
      *'#'*) view_args=("${ref##*#}" --repo "${ref%#*}") ;;
      '') ;;
      *) view_args=("$ref") ;;
    esac
    json=""
    for attempt in 1 2 3 4; do
      json=$(cd "${ref_cwd:-$HOME}" 2>/dev/null && gh pr view "${view_args[@]}" --json url,body 2>/dev/null) && [ -n "$json" ] && break
      json=""
      sleep $((attempt * 2))
    done
    if [ -z "$json" ]; then
      printf '%s fetch-failed ref=%q cwd=%q tool=%s\n' "$(date -Is)" "$ref" "$ref_cwd" "$tool_name" >> "$LOG"
      continue
    fi
    url=$(printf '%s' "$json" | jq -r .url)
    # https://<host>/<owner>/<repo>/pull/<n>
    path=$(printf '%s' "$url" | sed -E 's,^https?://([^/]+)/([^/]+)/([^/]+)/pull/([0-9]+).*,\1/\2/\3/\4,')
    dest="$SNAP_DIR/$path.jsonl"
    mkdir -p "$(dirname "$dest")"
    printf '%s' "$json" | SID="$session_id" TP="$transcript" RCWD="$ref_cwd" TOOL="$tool_name" python3 -I -c '
import sys, json, hashlib, os, datetime
d = json.load(sys.stdin)
norm = d["body"].replace("\r\n", "\n").rstrip()
print(json.dumps({
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "session_id": os.environ["SID"], "transcript_path": os.environ["TP"], "cwd": os.environ["RCWD"],
    "tool": os.environ["TOOL"], "url": d["url"], "sha256": hashlib.sha256(norm.encode()).hexdigest(),
    "body": d["body"]}))' >> "$dest"
  done <<< "$refs"
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
