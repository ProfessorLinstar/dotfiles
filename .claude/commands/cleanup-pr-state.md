---
name: cleanup-pr-state
description: Walk every session's PR tracking state in /tmp/claude-pr-state and drop entries whose PRs have been merged or closed. Removes session files that end up empty. Use to clear out stale state from long-running sessions or across reboots.
allowed-tools: Bash
---

# Cleanup PR state

Walk `/tmp/claude-pr-state/` across all sessions and remove tracked entries whose PRs are no longer open. Unlike `/refresh-pr-state` (which only touches the current session), this command operates globally.

## Step 1: Enumerate state files

```bash
ls -1 /tmp/claude-pr-state/ 2>/dev/null | grep -vE '^_'
```

Skip entries that start with `_` — those are pointer/index files maintained by the statusline, not session state.

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

For each state file:
- If any rows survive, rewrite the file atomically with just those rows.
- If no rows survive, delete the file.

## Step 4: Tidy up pointers

After processing all session files, prune dangling workspace pointers:

```bash
for ptr in /tmp/claude-pr-state/_by_workspace/*; do
  [ -f "$ptr" ] || continue
  target_key=$(cat "$ptr")
  if [ ! -f "/tmp/claude-pr-state/$target_key" ]; then
    rm -f "$ptr"
  fi
done
```

## Step 5: Report

Print a short summary:

- Sessions scanned
- Rows dropped, grouped by reason (merged/closed/unreachable)
- Session files deleted entirely (now empty)

Keep the report under 8 lines.
