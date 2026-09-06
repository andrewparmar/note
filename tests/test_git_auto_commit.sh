#!/bin/bash
set -euo pipefail

TMP=$(mktemp -d)
REMOTE="$TMP/remote.git"
MACHINE_A="$TMP/machine_a"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rm -rf "$TMP"; exit 1; }

git init --bare -q "$REMOTE"
git clone -q "$REMOTE" "$MACHINE_A"
git -C "$MACHINE_A" config user.email test@example.com
git -C "$MACHINE_A" config user.name test
# Multiple lines so machine A's append (bottom) and machine B's edit (top)
# land far enough apart that git's 3-way merge doesn't need to conflict —
# two single-line files both "appended to" is a textbook conflicting case.
printf 'line1\nline2\nline3\nline4\nline5\n' > "$MACHINE_A/notes.txt"
git -C "$MACHINE_A" add -A
git -C "$MACHINE_A" commit -q -m seed
git -C "$MACHINE_A" push -q origin master:main -u >/dev/null 2>&1 || \
git -C "$MACHINE_A" push -q origin HEAD:main

# "Machine B" must live at the exact path git_auto_commit.sh hardcodes
# ($HOME/Documents/notes), so clone it there directly under a fake $HOME.
HOME="$TMP/fake_home"
mkdir -p "$HOME/Documents"
git clone -q "$REMOTE" "$HOME/Documents/notes"
git -C "$HOME/Documents/notes" config user.email test@example.com
git -C "$HOME/Documents/notes" config user.name test

# Machine A commits and pushes first (simulates yesterday's cron on another machine)
echo "from machine A" >> "$MACHINE_A/notes.txt"
git -C "$MACHINE_A" add -A
git -C "$MACHINE_A" commit -q -m "from A"
git -C "$MACHINE_A" push -q origin HEAD:main

# Machine B has a local, non-conflicting change to the already-tracked
# notes.txt (unstaged changes to a tracked file) and is now behind origin/main.
# Prepending (rather than appending, like machine A) keeps the two edits in
# non-overlapping regions of the file so the rebase auto-merges cleanly.
sed -i.bak '1i\
from machine B
' "$HOME/Documents/notes/notes.txt"
rm -f "$HOME/Documents/notes/notes.txt.bak"

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/git_auto_commit.sh"
export HOME
bash "$SCRIPT" || fail "script exited non-zero on the non-conflicting rebase case"

git -C "$MACHINE_A" fetch -q origin
git -C "$MACHINE_A" log origin/main --oneline | grep -F "from A" > /dev/null || fail "machine A's commit missing from remote"
git -C "$HOME/Documents/notes" log --oneline | grep -F "from A" > /dev/null || fail "rebase did not pull machine A's commit"
git -C "$HOME/Documents/notes" log origin/main --oneline | grep -F "Automated commit" > /dev/null || fail "machine B's commit did not reach the remote"
pass "non-conflicting multi-machine push succeeds via pull --rebase"

rm -rf "$TMP"
echo "All tests passed."
