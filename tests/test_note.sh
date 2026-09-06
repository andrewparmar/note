#!/bin/bash
set -euo pipefail

TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
export EDITOR=true
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/,note"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rm -rf "$TMP_HOME"; exit 1; }

"$SCRIPT" >/dev/null
[ -f "$TMP_HOME/Documents/notes/notes.txt" ] || fail "notes.txt not created at \$HOME/Documents/notes/notes.txt"
pass "notes.txt created at \$HOME/Documents/notes/notes.txt"

if find "$TMP_HOME/Documents/notes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -q .; then
    fail "dated-file directories were created; dated-file mode must be removed"
fi
pass "no dated-file directories created"

"$SCRIPT" --personal >/dev/null
[ -f "$TMP_HOME/Documents/notes/personal_notes.txt" ] || fail "personal_notes.txt not created"
pass "personal_notes.txt created"

before=$(wc -l < "$TMP_HOME/Documents/notes/notes.txt")
"$SCRIPT" -r >/dev/null
after=$(wc -l < "$TMP_HOME/Documents/notes/notes.txt")
[ "$before" -eq "$after" ] || fail "-r mode appended a new entry"
pass "-r mode does not append a new entry"

printf '\n- \xe2\x80\xa0do the thing\n' >> "$TMP_HOME/Documents/notes/notes.txt"
"$SCRIPT" --todo | grep -q "do the thing" || fail "--todo did not find the marked line"
pass "--todo finds marked lines"

rm -rf "$TMP_HOME"
echo "All tests passed."
