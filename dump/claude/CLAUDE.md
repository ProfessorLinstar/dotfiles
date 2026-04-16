## Git
- Use `git -c commit.gpgsign=false ...` when making commits
- When making branches, name then "andywang/..." where ... is the intended change
- Always make sure that you're working with the right branch locally. If the user asks for changes to a particular PR, then you should check out that PR first locally before making your changes.
  - If there are untracked/unstaged changes, prompt the user for further instruction.
- Do not push commits / add comments in github / make new PRs unless explicitly told to do so.
  - You can and should make commits to the local branch without explicit permission
  - e.g. when the user says "Address this comment", make and commit the changes locally.

### Github PRs
- When making a new PR, respect the repository's PR description template (usually at `.github/PULL_REQUEST_TEMPLATE.md`)
- When editing a PR description, always check the previous state to make sure that you're not dropping important context.
- List resolved issues / related PRs at the top of the description
