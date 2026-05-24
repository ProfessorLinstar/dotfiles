---
name: refresh-pr-state
description: Refresh the per-session PR tracking state used by the statusline. Re-queries each tracked PR's state and base branch, drops closed/merged PRs, adds any PRs you know about from this conversation (current branch, or recent PRs you opened) that aren't yet tracked, and clears the push-pending flag. For walking related PRs you don't know about (pre-existing stacks created outside this session), use /discover-pr-state.
allowed-tools: Bash
---

# Refresh PR state

You maintain a per-session PR tracking file at `/tmp/claude-pr-state/<session_key>` that the statusline reads to display every PR the session is working on. Run this command after pushing, switching branches, or whenever the statusline stack order looks stale.

This command re-validates what's already tracked AND adds PRs you know about from this conversation but the hook may have missed (e.g. PRs opened via `cd /repo && gh pr create ...` where the hook's cwd didn't match the actual repo). It does NOT search the remote for unknown PRs — for that, follow up with `/discover-pr-state`.

## Step 1: Locate the state file

```bash
STATE_FILE=$(bash ~/.claude/scripts/pr-state.sh state-file)
```

The helper resolves the state file via a `_by_workspace/<md5($PWD)>` pointer the statusline maintains, falling back to the most-recently-modified session file. If `$STATE_FILE` is empty, there's nothing to refresh — report "no tracked PRs" and stop.

## Step 2: Re-query each PR

The state file is TSV with columns: `repo_root`, `branch`, `pr_url`, `base_branch`, `number`, `updated_at`.

For each row, query the PR's current state and base branch:

```bash
gh pr view "$PR_URL" --json state,baseRefName,headRefName,number 2>/dev/null
```

- Drop the row if `state` is `MERGED` or `CLOSED`.
- Otherwise update `base_branch` to the fresh `baseRefName`. Strip a trailing `-cached` suffix if present (Spr/restack-style stack tools target a cached mirror branch like `develop-cached` instead of the real base).
- Keep `repo_root` and `branch` (which is the local checkout key) unchanged.
- Bump `updated_at` to the current Unix timestamp.

Run the per-PR queries in parallel where possible (e.g. via xargs -P or a background-job loop) — there can be many tracked PRs.

## Step 3: Reconcile with what THIS conversation has been working on

The state file should reflect the PRs the session is actually focused on, not whatever branch happens to be checked out. You have the conversation context — use it as the source of truth.

Walk back through recent tool calls and results in this conversation. Build the set of PRs the session has been working on: ones you've created (`gh pr create`, `mcp__github__create_pull_request`, `gh api .../pulls -X POST`), pushed to (`git push` after opening a PR for that branch), edited descriptions on, monitored CI for, etc.

For each session-relevant PR not already in the state file:

1. Run `gh pr view <pr_url> --json url,baseRefName,headRefName,number,state 2>/dev/null` to fetch fresh metadata. (The URL contains the hostname, so this works for GHE too.)
2. If `state` is `OPEN` or `DRAFT`, append a new row. (`MERGED`/`CLOSED` PRs get dropped per Step 2.)
3. For `repo_root`, use the working directory the command was run in (e.g. the `cd <path>` immediately preceding the `gh` command, or your cwd at the time). For `branch`, use the PR's `headRefName`. For `base_branch`, use `baseRefName` with any trailing `-cached` suffix stripped.

**Do NOT auto-add the current branch's PR.** The currently checked-out branch may be unrelated to what the session is tracking (e.g. a test/exploration branch you switched to for a quick check). Only add it if it's already part of your session work per the conversation. The statusline will display the current branch separately below the tracked stack when it isn't part of it.

## Step 4: Write back and clear the flag

Rewrite the state file with the surviving rows (TSV, same column order) via the helper, then clear the push-pending flag:

```bash
printf '%s\n' "$row1" "$row2" ... | bash ~/.claude/scripts/pr-state.sh write-rows "$STATE_FILE"

SESSION_KEY=$(basename "$STATE_FILE")
bash ~/.claude/scripts/pr-state.sh clear-flag "$SESSION_KEY"
```

The statusline will re-render with the refreshed list on its next tick — no reload needed.

## Step 5: Report

Print a short summary:

- Number of PRs kept
- Number of PRs dropped (with their URLs and reason: merged/closed)
- The current branch's PR if newly added

Keep the report under 5 lines.
