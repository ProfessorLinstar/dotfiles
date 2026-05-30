#!/bin/bash
# refresh-pr-state-core: re-queries existing rows, drops merged/closed,
# adds new rows from stdin (pr_url\trepo_root), updates timestamp.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

CORE="$SCRIPTS_ROOT/refresh-pr-state-core.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
CI_DIR="$HOME/.local/state/claude/ci-state"
mkdir -p "$STATE_DIR" "$CI_DIR"

tx=$(mk_session refresh)
sk=$(session_key_of "$tx")
STATE="$STATE_DIR/$sk"

cat > "$STATE" <<EOF
$REPO	feat-1	https://example.com/pr/1	develop	1	100
$REPO	feat-2	https://example.com/pr/2	feat-1	2	100
$REPO	feat-merged	https://example.com/pr/3	develop	3	100
EOF

# Set a push-pending flag — refresh should clear it.
touch "$CI_DIR/push-pending-$sk"

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view https://example.com/pr/1 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/1\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-1\",\"number\":1,\"state\":\"OPEN\"}",
  "pr view https://example.com/pr/2 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/2\",\"baseRefName\":\"feat-1\",\"headRefName\":\"feat-2\",\"number\":2,\"state\":\"DRAFT\"}",
  "pr view https://example.com/pr/3 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/3\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-merged\",\"number\":3,\"state\":\"MERGED\"}",
  "pr view https://example.com/pr/4 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/4\",\"baseRefName\":\"develop-cached\",\"headRefName\":\"feat-new\",\"number\":4,\"state\":\"OPEN\"}"
}
JSON

# Add a new PR from stdin
out=$(printf 'https://example.com/pr/4\t%s\n' "$REPO" | bash "$CORE" "$STATE")

# Result: feat-1, feat-2, feat-new (3 rows, merged dropped)
line_count=$(wc -l < "$STATE")
assert_equal "$line_count" "3" "rows after refresh"
contents=$(cat "$STATE")
assert_contains "$contents" "feat-1" "kept feat-1"
assert_contains "$contents" "feat-2" "kept feat-2"
assert_contains "$contents" "feat-new" "added feat-new"
assert_not_contains "$contents" "feat-merged" "dropped merged"
# -cached stripped on the new row
new_base=$(awk -F'\t' '$2 == "feat-new" {print $4}' "$STATE")
assert_equal "$new_base" "develop" "-cached stripped from new row"

# Push-pending flag cleared
assert_file_missing "$CI_DIR/push-pending-$sk"

# Summary line printed
assert_contains "$out" "refresh:" "summary printed"

# Re-querying refreshes base_branch. Change fixture to return new base for pr/1.
cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr view https://example.com/pr/1 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/1\",\"baseRefName\":\"main\",\"headRefName\":\"feat-1\",\"number\":1,\"state\":\"OPEN\"}",
  "pr view https://example.com/pr/2 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/2\",\"baseRefName\":\"feat-1\",\"headRefName\":\"feat-2\",\"number\":2,\"state\":\"DRAFT\"}",
  "pr view https://example.com/pr/4 --json url,baseRefName,headRefName,number,state": "{\"url\":\"https://example.com/pr/4\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-new\",\"number\":4,\"state\":\"OPEN\"}"
}
JSON
printf '' | bash "$CORE" "$STATE" > /dev/null
new_base=$(awk -F'\t' '$2 == "feat-1" {print $4}' "$STATE")
assert_equal "$new_base" "main" "base_branch refreshed"

echo "refresh-pr-state-core ok"
