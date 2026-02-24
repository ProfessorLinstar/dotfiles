#!/bin/sh

# defaults
alias ls="ls --color=auto"                                      #
alias la="ls -la"                                               # list all with filesizes in MB
alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

# shortcuts
alias py=python3.10                                             # Python shortcut
alias activate=". venv/bin/activate"                            # Python virtual environment activation shortcut
alias vi=nvim                                                   #
alias vis="source vis"                                          # Allow vis to change cwd
alias gitu='git pull && git add -u && git commit && git push'   #
alias tt="gio trash"                                            # move file to trash

# git shortcuts
alias gs="git status"
alias gsn="git status -uno"
alias gd="git diff"
alias gds="git diff --staged"
alias gr="git restore --staged"
alias gc="git checkout"
alias ga="git add"
alias gam="ga -u && gm"
alias ghp="git stash push -u"
alias ghl="git stash list"
alias gmb="git merge-base"
alias gp="git push"
gg() {
  cd "$(git rev-parse --show-toplevel)"
}
gm() {
  if [ -z "$1" ]; then
    git commit
  else
    git commit -m "$1"
  fi
} 
gmp() { gm "$1" && git push }
gamp() { gam "$1" && git push }
gb() {
  rebase="$1"
  remote="$(git remote show)"

  command gh >/dev/null && target="$(gh pr view --json baseRefName -q '.baseRefName')"
  if [ -z "$target" ]; then
    echo "Could not use 'gh' to determine target branch."
  fi

  if [ -n "$rebase" ]; then
    echo "Using provided branch '$rebase' as rebase target."
  elif [ -n "$target" ]; then
    rebase="$target"
    echo "Using remote PR target branch '$rebase' as rebase target."
  else
    rebase="$(git rev-parse --abbrev-ref "$remote"/HEAD | sed "s@$remote/@@")"
    echo "Using remote HEAD '$rebase' as rebase target."
  fi

  if [ "$rebase" != "$target" ]; then
    echo "Warning: Remote target branch ('$target') is not the same as provided rebase branch ('$rebase')."
  fi

  if [ -z "$rebase" ]; then
    echo "Rebase branch could not be found."
    return 1
  fi

  cmd="git fetch && git fetch . "$remote/$rebase:$rebase" && git rebase -i "$rebase""
  echo "Command to run: $cmd"
  read -n 1
  echo "Running command..."
  eval "$cmd"
}

alias dnuke='docker kill $(docker ps -aq); docker rm -fv $(docker ps -aq)'
