# Syncing with upstream
This repo exists in two places that share one history:
- professorlinstar/dotfiles ("upstream"): the canonical repo.
- eldenmanking/dotfiles ("the fork"): a downstream copy, treated as low trust.

Both are public, so the rule against company-specific information applies to both. Changes flow between them by
merging, never by squashing or rebasing, so that each side's commits stay in the other's history.

## Trust
- Upstream merges the fork's changes only through a PR into upstream, reviewed like a contribution from a stranger,
  before they are merged or installed anywhere.
- Upstream never installs code from the fork: its defaults (below) name upstream's own repos.
- Machines that track upstream hold no credentials for the fork.
- The fork may merge upstream whenever it likes.

## Repo-specific lines
Each repo names itself and its own tools repo. A sync merge silently takes the other repo's values whenever only one
side changed these lines since the last merge, so restore them in the merge commit before pushing:

| File | Upstream | Fork |
|---|---|---|
| `install/features/claude.sh` (`TOOLS_DEFAULT_REPO`) | `ProfessorLinstar/tools` | `eldenmanking/tools` |
| `README.md` (install `curl` URLs, the `--claude` defaults and example) | `ProfessorLinstar` | `eldenmanking` |
| `.claude/CLAUDE.md` (the default tools repo) | `ProfessorLinstar/tools` | `eldenmanking/tools` |
| `docs/steamos-setup.md` (`git clone` URL) | `ProfessorLinstar/dotfiles` | `eldenmanking/dotfiles` |
| `tests/fixtures/{arch,steamos}-existing-rc/after/manifest` (`~/tools`) | `ProfessorLinstar/tools` | `eldenmanking/tools` |

In upstream, this should print nothing (in the fork, check for `ProfessorLinstar` instead):

```sh
git grep -nI eldenmanking -- install/features/claude.sh README.md .claude/CLAUDE.md docs/steamos-setup.md \
  tests/fixtures/arch-existing-rc tests/fixtures/steamos-existing-rc
```

TODO(andywang): decide whether upstream keeps installing tmux-resurrect from `eldenmanking/tmux-resurrect`
(`home/.tmux.conf`); if not, add it to the table.

## Syncing
From a clone of the repo being updated, with the other as a second remote:

```sh
git remote add fork https://github.com/eldenmanking/dotfiles   # in upstream; in the fork, add upstream instead
git fetch origin fork
git switch -c sync origin/main
git merge fork/main
# restore the repo-specific lines, check with the git grep above, then amend the merge commit
make check
```

Then land `sync` on `main` with a merge commit: in upstream, through a PR merged with "Create a merge commit"; in
the fork, likewise or by a direct push. Never force-push `main` in either repo. PRs that change only one repo may still
be squash-merged; it is the sync merge that must keep both parents.

Both repos run the same `install.sh`, so keep `docs/migrations.md` and the README tree up to date as usual.

## Claude Code config
Machine-wide Claude config isn't in either dotfiles repo: the `claude` feature installs it from tools repos
(`DOTFILES_TOOLS` in `README.md`). Upstream defaults to professorlinstar/tools, the fork to eldenmanking/tools, which
sync the same way. Work-specific config lives in a private tools repo that each work machine lists first in
`~/.config/dotfiles/tools.conf`; never name it in either public repo.

## History
The fork's history was rewritten to remove internal hostnames, repo names and PR/ticket references, and upstream's
history was rewritten to match on 2026-11-18, so both share every commit up to `39e1ec9` ("Fix dotfiles for coder",
2026-09-30). Authors, committers, dates and messages were kept; PGP signatures were stripped. The old commits stay
reachable by SHA until GitHub Support purges them, and any clone made before the rewrite must reset to the new
history (`git fetch && git reset --hard origin/<branch>`) or it will push the old commits back.

The first sync merge brought the fork's layout into upstream: `home/` and `root/`, `install/`, the SteamOS features,
and Claude config installed from tools repos instead of `light-install.sh`.
