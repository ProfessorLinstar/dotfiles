#!/bin/bash
# Parser gaps that silently dropped every PR in a session:
#
# (a) `GH_TOKEN=$(grep … | head -1) gh pr create …` — the `|` inside `$(…)` split the command, so the create sub
#     started with `head` and was skipped.
# (b) `git push … 2>&1` — the redirection was split into `2>`, `&`, `1`, each read as a refspec.
# (c) `B=feat; git push -u origin $B` — `$B` was looked up literally.
# (d) `git push origin HEAD` — HEAD was skipped and the current-branch fallback didn't apply.

set -e
source "$TEST_ROOT/lib/setup.sh"
test_init substvars

run_hook() {
  rm -f "$STATE_DIR/$SK"
  hook_input_bash "$1" "$REPO" "$TX" | bash "$HOOK"
}
state() { cat "$STATE_DIR/$SK" 2>/dev/null || echo; }

gh_fixture_pr feat-x OPEN develop 100

# --- (a) command substitution containing a pipe, as an env-var prefix.
run_hook "GH_TOKEN=\$(grep -o 'ghp_[A-Za-z0-9]*' ~/.git-credentials | head -1) gh pr create --draft --head feat-x --base develop --title t 2>&1"
assert_contains "$(state)" $'\tfeat-x\t' "(a) create behind \$(… | …) token prefix"

# --- (a2) backticks behave the same.
run_hook "GH_TOKEN=\`grep -o x f | head -1\` gh pr create -H feat-x"
assert_contains "$(state)" $'\tfeat-x\t' "(a2) create behind backtick token prefix"

# --- (a3) a heredoc body with an apostrophe inside \$(…) doesn't swallow the rest of the command.
body=$(printf 'gh pr create -H feat-x --body "$(cat <<'"'"'EOF'"'"'\nIt doesn'"'"'t (really) matter | at all\nEOF\n)" 2>&1')
run_hook "$body"
assert_contains "$(state)" $'\tfeat-x\t' "(a3) heredoc body inside \$(…)"

# --- (b) redirections aren't read as refspecs.
run_hook "git push -u origin feat-x 2>&1"
assert_contains "$(state)" $'\tfeat-x\t' "(b) push with 2>&1"
run_hook "git push origin feat-x >/tmp/out 2> /tmp/err"
assert_contains "$(state)" $'\tfeat-x\t' "(b2) push with file redirections"

# --- (c) variables assigned earlier in the same command are expanded.
run_hook "B=feat-x; git push -u origin \$B 2>&1"
assert_contains "$(state)" $'\tfeat-x\t' "(c) \$B resolved from earlier assignment"
run_hook "$(printf 'export B=feat-x\ngit push origin "${B}"')"
assert_contains "$(state)" $'\tfeat-x\t' "(c2) \${B} resolved across newline + export"

# --- (d) HEAD refspec and unresolvable branches use the current branch.
(cd "$REPO" && git checkout -q -b feat-x)
run_hook "git push origin HEAD"
assert_contains "$(state)" $'\tfeat-x\t' "(d) HEAD refspec → current branch"
run_hook "git push -u origin \$(git branch --show-current)"
assert_contains "$(state)" $'\tfeat-x\t' "(d2) unresolvable refspec → current branch"

# --- negative: an inline prefix assignment doesn't leak into later statements' expansion (bash semantics).
(cd "$REPO" && git checkout -q -b unrelated-current)
run_hook "B=feat-x true; git push origin \$B"
assert_not_contains "$(state)" $'\tfeat-x\t' "prefix assignment is not a shell variable"

echo "subst / redirect / var parsing ok"
