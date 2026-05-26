---
name: discover-pr-state
description: Discover sibling PRs in the same stack and add them to the session's PR tracking state. Walks baseRefName up and headRefName down from each tracked row using `gh pr list`. Use when the statusline is missing PRs that exist on the remote (e.g. created outside this session, or part of a pre-existing stack). For a routine refresh that doesn't search, use /refresh-pr-state instead.
allowed-tools: Bash
---

# Discover PR stack

Walk the base/head chain from each tracked PR to find related open PRs on the remote and add them to the session's state file. This is the heavier counterpart to `/refresh-pr-state`: it issues `gh pr list` calls and only makes sense when you suspect missing siblings.

## Step 1: Locate the state file

```bash
STATE_FILE=$(bash ~/.claude/scripts/pr-state.sh state-file)
```

The helper resolves THIS workspace's session state file via the `_by_workspace/<md5($PWD)>` pointer. The file may not exist yet. If `$STATE_FILE` is empty, the statusline hasn't rendered in this workspace yet — ask the user to wait a tick and retry, rather than touching another session's state.

## Step 1.5: Pick discovery seeds (in priority order)

The currently checked-out branch may be unrelated to what the session is tracking. **Prioritize session context over current branch.**

1. **Conversation context (primary).** Walk back through recent tool calls and identify the PRs THIS session has been working on (created, pushed to, edited, monitored). Use those PR URLs as the discovery seeds. For each, run `gh pr view <url> --json url,baseRefName,headRefName,number,state 2>/dev/null` and add a row to the working set if `state` is `OPEN` or `DRAFT` and it's not already tracked. Strip a trailing `-cached` from the resulting `baseRefName`.
2. **Existing state rows (secondary).** Any rows already in the state file.
3. **Current branch (last resort).** ONLY if (1) and (2) are both empty: if the current branch has an open PR, use it as the sole seed. Do NOT add it otherwise — the statusline will show it separately below the tracked stack.

If after these steps the seed set is empty, report "no seeds — nothing to discover from" and stop.

## Step 2: Walk the stack from each seed row

The state file is TSV with columns: `repo_root`, `branch`, `pr_url`, `base_branch`, `number`, `updated_at`. Maintain an in-memory set of `(repo_root, branch)` already known so a PR is never added twice.

For each row in the working set, run from its `repo_root`:

**Walk up (parents)** — find a PR whose head is this row's `base_branch`:

```bash
gh pr list --head "$BASE_BRANCH" --state open --json url,baseRefName,headRefName,number 2>/dev/null
```

If exactly one PR is returned and it's not already tracked, add it. Recurse with the new row's `baseRefName`. Stop when:
- the lookup returns zero or multiple results, or
- `base_branch` is a main-line branch (`main`, `master`, `develop`, `trunk`).

**Walk down (children)** — find PRs whose base is this row's `branch`:

```bash
gh pr list --base "$BRANCH" --state open --json url,baseRefName,headRefName,number 2>/dev/null
```

For each open PR returned that's not already tracked, add it. Recurse on each.

Cap total discovery at 20 newly-added PRs per repo to bound runtime. For each added row, `repo_root` is the seed row's `repo_root`, `branch` is the discovered PR's `headRefName`, `pr_url` is its `url`, `base_branch` is its `baseRefName` with any trailing `-cached` suffix stripped (Spr/restack-style stack tools target a cached mirror branch like `develop-cached`), `number` is its `number`, `updated_at` is now.

When walking up via `$BASE_BRANCH`, also strip a trailing `-cached` from the source row's `base_branch` before looking up, so the walk targets the real parent branch.

This command does NOT re-validate or drop existing rows — that's `/refresh-pr-state`'s job. Run that first if rows might be stale.

## Step 3: Write back

Rewrite the state file with the union of original rows and discovered rows via the helper (keeps the TSV column order):

```bash
printf '%s\n' "$row1" "$row2" ... | bash ~/.claude/scripts/pr-state.sh write-rows "$STATE_FILE"
```

## Step 4: Report

Print a short summary:

- Seed rows considered
- New PRs discovered (with their numbers and reason: walked up via base, walked down via head)
- Any walks that bailed (multiple matches for a head — these are ambiguous on purpose)

Keep the report under 6 lines.
