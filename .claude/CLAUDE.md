# Added by dotfiles
## Git
- Use `git -c commit.gpgsign=false ...` when making commits
- When making branches, name then "andywang/..." where ... is the intended change
- Always make sure that you're working with the right branch locally. If the user asks for changes to a particular PR, then you should check out that PR first locally before making your changes.
  - If there are untracked/unstaged changes, prompt the user for further instruction.
- You can and should make commits to the local branch without explicit permission
    - e.g. when the user says "Address this comment", make and commit the changes locally.
- Only push changes to remote if there is not a PR open for the current branch or if the PR is a draft

### Github PRs
- Do not add comments in github without explicit permission
- When making a new PR, respect the repository's PR description template (usually at `.github/PULL_REQUEST_TEMPLATE.md`)
- When editing a PR description, always check the previous state to make sure that you're not dropping important context.
- List resolved issues / related PRs at the top of the description
- When a PR fixes an issue, add `fixes <issue-url>` to the start of the description
- When updating a PR description for a stacked PR, add the stack to the start of the description, with 👈 marking the current PR:
  ```
  - #xxxxx
  - #xxxxx 👈
  - #xxxxx
  ```
- When retargeting a stacked PR (e.g. after a parent PR merges), update the stack list in the description accordingly.
# /Added by dotfiles
