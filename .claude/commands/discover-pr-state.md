---
name: discover-pr-state
description: Discover sibling PRs in the same stack and add them to the session's PR tracking state. Walks baseRefName up and headRefName down from each tracked row using `gh pr list`. Use when the statusline is missing PRs that exist on the remote (e.g. created outside this session, or part of a pre-existing stack). For a routine refresh that doesn't search, use /refresh-pr-state instead.
allowed-tools: Bash
---

# Discover PR stack

Walk the base/head chain from each tracked PR to find related open PRs on the remote and add them to the session's state file. Heavier than `/refresh-pr-state` because it issues `gh pr list` calls.

The deterministic walk lives in `~/.claude/scripts/discover-pr-state-core.sh`. Your job is to pick the right seed rows.

## Step 1: Locate the state file

```bash
STATE_FILE=$(bash ~/.claude/scripts/pr-state.sh state-file)
```

If `$STATE_FILE` is empty the statusline hasn't rendered in this workspace yet — ask the user to wait one render tick.

## Step 2: Pick discovery seeds (in priority order)

The currently-checked-out branch may be unrelated to session focus. **Prioritize conversation context over current branch.**

1. **Conversation context (primary).** Walk back through recent tool calls and identify the PRs THIS session has been working on. Use those as seeds.
2. **Existing state rows (secondary).** The core script automatically uses every row already in the state file as a seed, so you don't need to repeat them on stdin.
3. **Current branch (last resort).** ONLY if (1) is empty AND the state file is empty: if the current branch has an open PR, use it as the sole seed.

If after these steps you have no seeds AND the state file is empty, report "no seeds — nothing to discover from" and stop.

## Step 3: Hand seeds to the core script

```bash
printf '%s\n' \
  "$REPO	feat-x	https://example.com/pr/100	develop	100" \
  ... \
  | bash ~/.claude/scripts/discover-pr-state-core.sh "$STATE_FILE"
```

Each stdin line is a full TSV row: `repo_root\tbranch\tpr_url\tbase_branch\tnumber` (TABs, not spaces, 5 columns). The core script:

- Walks up from each row's `base_branch` via `gh pr list --head <base>`. Single match = parent found; multi-match = bail.
- Walks down from each row's `branch` via `gh pr list --base <branch>`. Multi-match is fine; recurses on each.
- Stops at main-line branches (`main`/`master`/`develop`/`trunk`).
- Strips `-cached` suffix on any newly-added `base_branch`.
- Caps at 20 new PRs per repo.

Pass an empty stdin (`printf '' | bash ...`) to walk from existing rows only.

## Step 4: Report

The core prints a one-line summary (`added=N`) and any bail reasons. Surface them. Keep the report under 6 lines.
