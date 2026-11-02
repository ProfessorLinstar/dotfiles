# Added by dotfiles
## Git
- For draft PRs or branches without a PR, always use `git -c commit.gpgsign=false ...` when making commits. For PRs that are ready for review, always sign commits.
- When making branches, name then "andywang/..." where ... is the intended change
- Always make sure that you're working with the right branch locally. If the user asks for changes to a particular PR, then you should check out that PR first locally before making your changes.
  - If there are untracked/unstaged changes, prompt the user for further instruction.
- You can and should make commits to the local branch without explicit permission.
- Only push changes to remote if there is not a PR open for the current branch or if the PR is a draft

### Github PRs
- When iterating on an open or draft PR, add new commits instead of amending existing ones and force pushing
- Prefix the first commit message with \[PR-start <branch-name>\]
- Never add comments in github unless I say exactly to "reply" to a comment.
- Double check for permission before adding comments.
- Always create PRs in draft mode, never ready for review
- When marking a PR as ready for review, sign and rebase the PR if any commits are unsigned
- When writing a PR description:
  - For new PRs, respect the repository's PR description template (usually at `.github/PULL_REQUEST_TEMPLATE.md`).
  - For existing PRs, always check the previous state to make sure that you're not dropping important context.
  - Header lines at the top (only what applies; always include newlines after a list):
    ```
    Main issue: <url> / Fixes <url> / Part N/? of <url> / FLUP to <url> / Short term fix for: <url> / Preflight for: <pr> / <X> mirror of <pr> <!-- only pick one of these -->
    Context: <slack-thread-or-review-comment-url>

    Replaces #xxxxx (collapsed commit history; description preserved).

    Related PRs:
    - #xxxxx

    Depends on:
    - https://github.palantir.build/org/repo/pull/xxxxx (short title)

    PR stack:
    - #xxxxx
    - #xxxxx 👈
    - #xxxxx
    ```
    - `Fixes`/`Context` targets may be issues, issue comments, Slack threads, PDH/infosec tickets, or Meticulous runs. Prefer the most specific issue over umbrella issues.
    - If I haven't given you a Slack thread, search for one first (e.g. the `search-slack` skill, with the PR/branch link or key terms). Only if nothing matches, ask me rather than omitting or guessing.
    - If the PR fixes a regression introduced by other PRs, find them and list them under `Fixes:`.
    - Only list PRs a reviewer needs; don't add superseded attempts or loosely related PRs found by searching.
    - Use 👈 to mark the current PR in a stack. Use #xxxxx for PRs in the same repo and full URLs otherwise.
  - Body: lead with `Previously, <problem>.` then `This PR …` / `Now, …`. Explain behavior and motivation, not a file-by-file changelog. Keep length proportional; bumps and one-liners get 1–2 sentences.
    - Version bumps: just `This picks up the following:` plus a list of the upstream PRs (and `Context:` if any). No problem statement, logs, or caveats; add a `Verify that …` item only when there is a test PR to link.
    - Call out caveats (`Note that …`), alternatives considered (`We could …, but … Instead, …`), and follow-ups (`We should revert this once …`).
    - Link code with SHA permalinks; paste relevant logs or CLI output in code blocks.
    - Never invent rationale, tickets, or verification. If the "why" is unknown, ask me or write `TODO(andywang): why`.
  - Testing: `Verify that …` checklist items; unit tests in one line (`Add unit tests to verify that …`).
    - Nest evidence (test PRs, CircleCI/Gradle scan links, gists) under each item. Use tables for scenario matrices.
    - Cover edge cases and the unchanged path (e.g. `Confirm X behaves as before`).
    - For anything a user can see (including which items are selected/enabled), add a screenshot placeholder under each manual item, or `Before:`/`After:` placeholders. Use `N/A` when trivial.
    - Only check `[x]` with evidence; otherwise leave `[ ]`.
  - Templates: keep `==COMMIT_MSG==` to a single line and keep required boilerplate (e.g. Environment Compatibility) verbatim. Drop sections and checkboxes that don't apply. No template → plain prose. Bot-generated backports: keep the bot body; only append.
- When retargeting a stacked PR (e.g. after a parent PR merges), update the stack list in the description accordingly.


## Commenting
- You may author trivial comments yourself, as well as new comments that are straightforward and have strong precedent in the surrounding code for what they should look like.
- Otherwise, whenever something needs to be documented in code (e.g. javadocs), add a `TODO(andywang): add comment` instead.
- If an existing comment should be changed, add `TODO(andywang): update comment` instead, unless the change is trivial.
- You may copy comments verbatim, but if the comment needs to be adapted non-trivially, then add `TODO(andywang): update comment` instead.
- If some behavior deserves explanation, you may add a github comment IF the PR is in draft mode. Otherwise flag this to the user directly.

## Formatting
- Don't manually wrap markdown unless existing code already does it
- Wrap comments with a text width of 120 characters
# /Added by dotfiles
