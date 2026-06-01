#!/bin/bash
# discover-pr-state-core: walks up via base→head (single match), down via
# head→base (multi OK), strips -cached, bails on ambiguous up-walks,
# stops at main-line.

set -e
source "$TEST_ROOT/lib/sandbox.sh"
source "$TEST_ROOT/lib/assert.sh"
mk_sandbox

CORE="$SCRIPTS_ROOT/discover-pr-state-core.sh"
STATE_DIR="$HOME/.local/state/claude/pr-state"
mkdir -p "$STATE_DIR"

tx=$(mk_session disc)
sk=$(session_key_of "$tx")
STATE="$STATE_DIR/$sk"

# Seed: a middle PR (feat-2). Stack is:
#   develop ← feat-1 ← feat-2 ← feat-3 (one child)
#                                ← feat-3b (sibling child — multiple-match)
# walk_up from feat-2's base (feat-1) should find feat-1, then stop at develop.
# walk_down from feat-2 should find both feat-3 and feat-3b.
cat > "$STATE" <<EOF
$REPO	feat-2	https://example.com/pr/2	feat-1	2	100
EOF

cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr list --head feat-1 --state open --json url,baseRefName,headRefName,number": "[{\"url\":\"https://example.com/pr/1\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-1\",\"number\":1}]",
  "pr list --head develop --state open --json url,baseRefName,headRefName,number": "[]",
  "pr list --base feat-2 --state open --json url,baseRefName,headRefName,number": "[{\"url\":\"https://example.com/pr/3\",\"baseRefName\":\"feat-2\",\"headRefName\":\"feat-3\",\"number\":3},{\"url\":\"https://example.com/pr/3b\",\"baseRefName\":\"feat-2\",\"headRefName\":\"feat-3b\",\"number\":31}]",
  "pr list --base feat-3 --state open --json url,baseRefName,headRefName,number": "[]",
  "pr list --base feat-3b --state open --json url,baseRefName,headRefName,number": "[]"
}
JSON

out=$(printf '' | bash "$CORE" "$STATE")

# Result: feat-1, feat-2, feat-3, feat-3b (4 rows)
line_count=$(wc -l < "$STATE")
assert_equal "$line_count" "4" "rows after discovery"
contents=$(cat "$STATE")
assert_contains "$contents" $'\tfeat-1\t' "walked up to feat-1"
assert_contains "$contents" $'\tfeat-3\t' "walked down to feat-3"
assert_contains "$contents" $'\tfeat-3b\t' "walked down to sibling feat-3b"
assert_contains "$out" "added=3" "summary shows 3 added"

# --- Ambiguous up-walk bails (multiple matches → no add, recorded in bails)
rm "$STATE"
cat > "$STATE" <<EOF
$REPO	feat-2	https://example.com/pr/2	feat-x	2	100
EOF
cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr list --head feat-x --state open --json url,baseRefName,headRefName,number": "[{\"url\":\"https://example.com/pr/a\",\"baseRefName\":\"develop\",\"headRefName\":\"feat-x\",\"number\":7},{\"url\":\"https://example.com/pr/b\",\"baseRefName\":\"main\",\"headRefName\":\"feat-x\",\"number\":8}]",
  "pr list --base feat-2 --state open --json url,baseRefName,headRefName,number": "[]"
}
JSON
out=$(printf '' | bash "$CORE" "$STATE")
contents=$(cat "$STATE")
assert_not_contains "$contents" $'\tfeat-x\thttps://' "ambiguous up-walk did not add"
assert_contains "$out" "up-ambig" "bail recorded"

# --- -cached suffix stripped at discovery
rm "$STATE"
cat > "$STATE" <<EOF
$REPO	feat-2	https://example.com/pr/2	feat-1-cached	2	100
EOF
cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr list --head feat-1 --state open --json url,baseRefName,headRefName,number": "[{\"url\":\"https://example.com/pr/1\",\"baseRefName\":\"develop-cached\",\"headRefName\":\"feat-1\",\"number\":1}]",
  "pr list --head develop --state open --json url,baseRefName,headRefName,number": "[]",
  "pr list --base feat-2 --state open --json url,baseRefName,headRefName,number": "[]"
}
JSON
printf '' | bash "$CORE" "$STATE" > /dev/null
new_base=$(awk -F'\t' '$2 == "feat-1" {print $4}' "$STATE")
assert_equal "$new_base" "develop" "-cached stripped on added row"

# --- Stops at main-line: up-walk to develop returns no further hop
# (already exercised by first sub-test — develop fixture returns [])

# --- Stdin seed picks up a PR not in existing state
rm "$STATE"
: > "$STATE"
cat > "$GH_MOCK_FIXTURE" <<'JSON'
{
  "pr list --head develop --state open --json url,baseRefName,headRefName,number": "[]",
  "pr list --base feat-seed --state open --json url,baseRefName,headRefName,number": "[]"
}
JSON
printf '%s\tfeat-seed\thttps://example.com/pr/seed\tdevelop\t99\t100\n' "$REPO" \
  | bash "$CORE" "$STATE" > /dev/null
contents=$(cat "$STATE")
assert_contains "$contents" "feat-seed" "stdin seed ingested"

echo "discover-pr-state-core ok"
