---
name: cleanup-pr-state
description: Walk every session's PR tracking state and drop entries whose PRs have been merged or closed. Removes session files that end up empty. Use to clear out stale state from long-running sessions or across reboots.
allowed-tools: Bash
---

# Cleanup PR state

Walk the global PR state directory and remove tracked entries whose PRs are no longer open. Unlike `/refresh-pr-state` (current session only), this command operates across every session.

## Step 1: Enumerate state files

```bash
STATE_DIR=$(bash ~/.claude/scripts/pr-state.sh state-dir)
ls -1 "$STATE_DIR" 2>/dev/null | grep -vE '^_'
```

The `_by_workspace` pointer directory is skipped — those aren't session state.

## Step 2: For each state file, filter rows

The state file is TSV with columns: `repo_root`, `branch`, `pr_url`, `base_branch`, `number`, `updated_at`.

For each row, query the PR's state:

```bash
gh pr view "$PR_URL" --json state 2>/dev/null | jq -r '.state // empty'
```

- Drop rows whose state is `MERGED` or `CLOSED`.
- Drop rows where the `gh pr view` call fails outright (PR deleted, no auth, etc.) — they can be re-added by `/refresh-pr-state` if still relevant.
- Keep rows whose state is `OPEN` or `DRAFT`.

Run PR queries in parallel where possible — across all sessions there may be many.

## Step 3: Rewrite or delete

For each state file at path `$STATE_DIR/<session>`:
- If any rows survive, rewrite atomically via the helper:
  ```bash
  printf '%s\n' "$row1" "$row2" ... | bash ~/.claude/scripts/pr-state.sh write-rows "$STATE_DIR/<session>"
  ```
- If no rows survive, delete the file:
  ```bash
  bash ~/.claude/scripts/pr-state.sh drop-state "$STATE_DIR/<session>"
  ```

## Step 4: Tidy up pointers

After processing all session files, prune dangling `_by_workspace` pointers:

```bash
bash ~/.claude/scripts/pr-state.sh prune-pointers
```

## Step 5: Report

Print a short summary:

- Sessions scanned
- Rows dropped, grouped by reason (merged/closed/unreachable)
- Session files deleted entirely (now empty)

Keep the report under 8 lines.
