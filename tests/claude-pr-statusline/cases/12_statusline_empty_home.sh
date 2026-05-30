#!/bin/bash
# `shorten()` must not match arbitrary paths when HOME is empty. Tested by
# extracting the function body from statusline.sh and running it with
# HOME="" — the result for an absolute path must NOT begin with `~`.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

# Extract shorten() from the live statusline script.
shorten_src=$(awk '/^shorten\(\) \{/,/^\}/' "$SCRIPTS_ROOT/statusline.sh")
[ -n "$shorten_src" ] || _fail "couldn't extract shorten() source"

eval "$shorten_src"

# HOME set, path matches → shortened
HOME_BACKUP=$HOME
HOME=/home/user
out=$(shorten "/home/user/proj")
assert_equal "$out" "~/proj" "shorten with matching prefix"

# HOME set, path doesn't match → unchanged
out=$(shorten "/var/lib/foo")
assert_equal "$out" "/var/lib/foo" "shorten with no prefix match"

# HOME empty → must NOT match anything
HOME=""
out=$(shorten "/etc/passwd")
assert_equal "$out" "/etc/passwd" "shorten with empty HOME passes through"

HOME=$HOME_BACKUP
echo "shorten() empty-HOME guard ok"
