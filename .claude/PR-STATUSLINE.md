# PR statusline

Multi-line Claude Code statusline that shows every PR a session is tracking, with the current branch highlighted (or shown separately when unrelated to the tracked stack). Built so Claude can curate the list from conversation context, with hooks doing automated capture and a few slash commands for repair/discovery.

This doc is the high-level map for anyone working on the feature. Code lives under `~/.claude/scripts/` (symlinked from `dotfiles/.claude/scripts/`) and `~/.claude/commands/` (symlinked from `dotfiles/.claude/commands/`).

---

## What you see

```
  ~/git/forge  andywang/conjure-1  https://github.palantir.build/foundry/forge/pull/234940
  ~/git/forge  andywang/conjure-2  https://github.palantir.build/foundry/forge/pull/234963
▶ ~/git/forge  andywang/conjure-3  https://github.palantir.build/foundry/forge/pull/234969
42%
```

- Tracked PRs, grouped by repo, stack-sorted (parent→child via `baseRefName` walk within a repo).
- `▶` marks the current `(repo_root, branch)` when it matches a tracked row.
- If the current `(repo_root, branch)` is unrelated to anything tracked, it renders as a separate block below the stack with a blank-line separator. (The current branch may be a test/exploration branch — don't conflate with the session's actual focus.)
- Trailing line is the context-window percentage.

When no state exists for the session, a legacy single-line view (`<cwd> <branch> <pr-url> <ctx%>`) is used as a fallback.

---

## Architecture

```
                  ┌─────────────────────────────┐
                  │   ~/.local/state/claude/    │
                  │   ├── pr-state/             │
                  │   │   ├── <session_key>     │  TSV: repo, branch,
                  │   │   ├── ...               │       pr_url, base,
                  │   │   └── _by_workspace/    │       num, updated_at
                  │   │       └── <md5($PWD)>   │  → session_key
                  │   ├── ci-state/             │
                  │   │   └── push-pending-<sk> │  PR URL of last push
                  │   └── pr-cache/             │
                  │       └── <md5(repo_root)>  │  legacy fallback
                  └─────────────────────────────┘
                            ▲       ▲
       writes/reads ────────┘       └──── reads (statusline)
                            │       │
       ┌────────────────────┴───┐ ┌─┴────────────────┐
       │ post-push-ci.sh (hook) │ │  statusline.sh   │
       │ PostToolUse on push/   │ │  Per-render. Also │
       │ PR create. Auto-       │ │  writes the      │
       │ captures session work. │ │  _by_workspace   │
       └────────────────────────┘ │  pointer.        │
                                  └──────────────────┘
                                          ▲
                                          │ reads only
                            ┌─────────────┴─────────────┐
                            │ stop-ci-check.sh (Stop)   │
                            │ Blocks Stop on            │
                            │ push-pending; tells       │
                            │ Claude to babysit-ci +    │
                            │ /refresh-pr-state.        │
                            └───────────────────────────┘
                                          ▲
                                          │ called via Bash tool
                            ┌─────────────┴─────────────┐
                            │  pr-state.sh (helper)     │
                            │  Single allowlisted Bash  │
                            │  command. Slash commands  │
                            │  go through it for all    │
                            │  state mutations.         │
                            └───────────────────────────┘
                                          ▲
                                          │
                  ┌───────────────────────┼──────────────────────┐
                  │                       │                      │
       /refresh-pr-state         /discover-pr-state       /cleanup-pr-state
       Reconcile state with      Walk gh pr list from     Walk every session's
       conversation context.     existing seeds (head/    state, drop closed/
       Drop MERGED/CLOSED.       base chain). Heavy.      merged PRs globally.
       Add PRs Claude knows
       about from this session.
```

---

## State files

All under `~/.local/state/claude/` (persistent across `/tmp` wipes and `--resume`).

### `pr-state/<session_key>` — per-session TSV

- `session_key = md5(transcript_path)` (or `md5(session_id)` if no transcript).
- Columns (TAB-separated):
  1. `repo_root` — git toplevel of the repo
  2. `branch` — the PR's `headRefName` (typically equals the local branch name when checked out)
  3. `pr_url`
  4. `base_branch` — `baseRefName` with any `-cached` suffix stripped (Spr/restack stack tools target a `develop-cached` mirror)
  5. `number`
  6. `updated_at` — Unix timestamp
- Dedup key: `(repo_root, branch)`. Pushing the same branch repeatedly updates; switching branches in the same workdir adds new rows.

### `pr-state/_by_workspace/<md5($PWD)>` — workspace pointer

- Contents: a single `session_key` line.
- Written by the statusline on every render.
- Read by slash commands to find "which session's state file should I touch for this workspace?"
- Critical: do NOT fall back to "most recent state file" when the pointer is missing or stale — silent cross-session corruption is worse than refusing. Helper returns empty in that case.

### `ci-state/push-pending-<session_key>` — Stop nudge flag

- Contents: a PR URL.
- Written by the post-push hook on any push/create.
- Read by the Stop hook to block Claude from stopping until it spawns `/babysit-ci` and runs `/refresh-pr-state`.
- Cleared via `pr-state.sh clear-flag <session_key>`.

### `pr-cache/<md5(repo_root)>` — legacy fallback cache

- Used only by the statusline's single-line fallback when no session state exists.
- Lazy-populated via `gh pr view` per repo on first render.

---

## Components

### `post-push-ci.sh` — PostToolUse hook

Fires on `Bash` and `mcp__github__create_pull_request`. Detects:

- `gh pr create` (Bash): parses `-H/--head <branch>` from args. Handles batches (e.g. `gh pr create -H a && gh pr create -H b`).
- `gh api -X POST .../pulls -f head=<branch>`: parses `-f head=` form.
- `mcp__github__create_pull_request`: reads `.tool_input.head`.
- `git push` (Bash): falls back to the currently checked-out branch.

For each captured head, runs `gh pr view <head> --json url,baseRefName,headRefName,number,state` from the repo root, strips `-cached` from `baseRefName`, and writes a row to the session state file. Sets the `push-pending` flag with the last PR URL.

**Hooks bypass Bash tool permission prompts**, so the hook can write anywhere without user approval.

**Failure modes**:
- If `cd /other/repo && gh pr create ...` is in the cmd, the hook's `cwd` is the calling cwd, not `/other/repo`. The `gh pr view <head>` from the wrong repo returns nothing → row not added. `/refresh-pr-state`'s conversation-context cross-check is the recovery path for this.

### `stop-ci-check.sh` — Stop hook

If `push-pending-<session_key>` exists, exits 2 with stderr telling Claude to:
1. Spawn a background `/babysit-ci <pr_url>` agent.
2. Run `/refresh-pr-state`.
3. Clear the flag via the helper.

### `statusline.sh` — statusLine command

Reads JSON from stdin (Claude Code contract: `workspace.current_dir`, `context_window.used_percentage`, `transcript_path`). Always writes the `_by_workspace/<md5($PWD)>` pointer.

If session state file exists and non-empty:
- Stack-sorts within each repo via an embedded awk routine (BFS via `base_branch` parent walk; insertion sort by `(repo, depth)`).
- Renders one row per tracked PR; current row gets `▶ ` and bold/blue/green/purple palette, others get dim.
- If current `(repo_root, branch)` isn't in the stack, appends a blank-line separator and a "▶ current  branch  (no PR or url-from-cache)" block beneath.

Otherwise renders single-line legacy view.

ANSI escape sequences are hardcoded; if you change colors, also update the comment-block convention.

### `pr-state.sh` — mutation helper

Single-purpose script invoked by slash commands. Subcommands:

| subcommand | purpose |
|---|---|
| `state-dir` | print state directory |
| `ci-dir` | print ci-state directory |
| `state-file` | print THIS workspace's session state file path (may not exist; empty if no pointer) |
| `write-rows <target>` | atomic replace `<target>` from stdin (must live under state-dir) |
| `clear-flag <session_key>` | rm push-pending flag |
| `drop-state <target>` | rm a session state file |
| `prune-pointers` | rm `_by_workspace` pointers whose target session file no longer exists |

Refuses to touch paths outside `state-dir` (`guard_state_path`). Refuses malformed session keys (containing `/` or `..`).

Allowlisted with `Bash(bash ~/.claude/scripts/pr-state.sh:*)` in `settings.json` so slash commands don't trigger per-mutation Bash permission prompts.

### Slash commands (markdown skill files)

#### `/refresh-pr-state`
Lean default. Reconciles state with conversation context:
1. Locate state file via `pr-state.sh state-file`.
2. Re-query each tracked row, drop MERGED/CLOSED, refresh `base_branch`.
3. Walk conversation context for PRs Claude has worked on; add any missing OPEN/DRAFT ones.
4. Write back via `pr-state.sh write-rows`; clear flag via `pr-state.sh clear-flag`.
5. Report.

**Does NOT auto-add the current branch's PR** — the current branch may be unrelated to session focus. Only adds if the PR is in conversation context.

#### `/discover-pr-state`
Heavy, on-demand. Walks `gh pr list --head/--base` from seed rows.
1. Locate state file.
2. Seeds in priority order: (a) PRs from conversation context, (b) existing state rows, (c) current branch's PR — last resort only.
3. Walk up via `base_branch` (one hop = `gh pr list --head <base>`, expects exactly one match), walk down via `branch` (`gh pr list --base <head>`, multiple OK). Cap 20 new PRs/repo.
4. Write back via helper. Doesn't drop or re-query existing rows.

#### `/cleanup-pr-state`
Cross-session cleanup. Walks every file in `pr-state/`, queries each PR, drops MERGED/CLOSED, deletes empty session files, prunes dangling workspace pointers.

---

## Lifecycles

### Normal push flow
1. Claude runs `gh pr create -H X` (or `git push`).
2. PostToolUse `post-push-ci.sh` fires, looks up the PR, adds/updates a row, sets `push-pending` flag.
3. Stop hook reads flag → Claude spawns `/babysit-ci`, runs `/refresh-pr-state`, then helper clears the flag.
4. Statusline picks up the new row on its next render tick.

### Cross-repo session
- Session worked in `~/git/forge` (added rows) and `~/git/scratch` (added rows).
- Both repos appear as separate groups in the statusline, stack-sorted within each.

### `--resume`
- `transcript_path` is preserved → `session_key` is preserved → state file at `~/.local/state/claude/pr-state/<session_key>` survives.
- Statusline re-renders with the same tracked rows.

### Current branch unrelated to tracked stack
- Tracked: forge PRs from earlier in the session.
- User `cd`s to `~/git/wizardry` to investigate something on a non-PR branch.
- Statusline shows tracked forge stack at top, blank line, then `▶ ~/git/wizardry  feat-x  (no PR)` block below.

---

## Known sharp edges / improvement opportunities

- **Stack rendering is single-line per row.** Long PR URLs overflow narrow terminals. Width-aware truncation (`#num` instead of URL, etc.) hasn't been implemented. See the conversation in the design discussion for sketched-but-not-built approaches.
- **Vertical-space cap missing.** Sessions tracking many PRs produce many statusline rows. No mechanism yet to cap height with a "+N more" indicator that always preserves the current row.
- **Stack walking is per-repo only.** No cross-repo stack relationships even when PRs reference each other.
- **`gh pr view` is sequential in the hook.** For batched creates, the loop runs N synchronous `gh` calls. Parallelizing would speed things up but introduce locking concerns on the state file write path.
- **Stale `pr-cache/` entries.** Legacy lazy-lookup cache never invalidates after a branch switch. Pre-existing bug; fallback path only.
- **`_by_workspace` pointer collisions.** Two Claude sessions in the same workspace will fight over the same pointer; last-render wins. Rare but possible.
- **`-cached` suffix is hardcoded.** Other stack-tool conventions (e.g. SPR's `spr/` prefix branches) aren't recognized. Add another normalization rule if needed.
- **Helper guard accepts any path under `state-dir`, including `_by_workspace/<key>`.** A malicious caller could write nonsense pointer data, though attack surface is limited to the local user.

## Testing

- **Syntax:** `bash -n` on each script.
- **Statusline rendering:** pipe a mock JSON to `statusline.sh` and ANSI-strip the output:
  ```bash
  echo '{"workspace":{"current_dir":"..."},"context_window":{"used_percentage":42.0},"transcript_path":"..."}' \
    | bash ~/.claude/scripts/statusline.sh | sed 's/\x1b\[[0-9;]*m//g'
  ```
- **Helper:** the file under `dotfiles/.claude/scripts/pr-state.sh` has self-contained subcommands; spot-check each (`state-dir`, `state-file`, `write-rows`, `clear-flag`, `drop-state`, `prune-pointers`).
- **Hook:** the `gh pr view` integration requires real GitHub auth. Unit-testable parts are the head parsing (`-H/--head`, `-f head=`) and the cwd → repo_root canonicalization.

## File map

| Path | Role |
|---|---|
| `dotfiles/.claude/scripts/post-push-ci.sh` | PostToolUse hook |
| `dotfiles/.claude/scripts/stop-ci-check.sh` | Stop hook |
| `dotfiles/.claude/scripts/statusline.sh` | statusLine command |
| `dotfiles/.claude/scripts/pr-state.sh` | Mutation helper |
| `dotfiles/.claude/commands/refresh-pr-state.md` | Default refresh skill |
| `dotfiles/.claude/commands/discover-pr-state.md` | Stack discovery skill |
| `dotfiles/.claude/commands/cleanup-pr-state.md` | Global cleanup skill |
| `dotfiles/dump/claude/settings.json` | Hook + statusline + permission config (deep-merged on install) |
| `dotfiles/light-install.sh` | Symlinks scripts/commands into `~/.claude/`, merges settings |
