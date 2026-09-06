#!/bin/bash
set -euo pipefail

TMP_HOME=$(mktemp -d)
NOTE_DIR="$TMP_HOME/Development/note"
mkdir -p "$NOTE_DIR" "$TMP_HOME/bin"
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh" "$NOTE_DIR/install.sh"
touch "$NOTE_DIR/,note" "$NOTE_DIR/git_auto_commit.sh"

# stub crontab to capture what would be installed, instead of touching the real one
STUB_BIN="$TMP_HOME/stubbin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/crontab" <<'EOF'
#!/bin/bash
if [ "$1" = "-l" ]; then
    cat "$CRONTAB_CAPTURE" 2>/dev/null
    exit 0
fi
cat > "$CRONTAB_CAPTURE"
EOF
chmod +x "$STUB_BIN/crontab"

# stub ,note so a stray command-substitution execution is detectable
cat > "$STUB_BIN/,note" <<'EOF'
#!/bin/bash
echo "SENTINEL: ,note was executed during install" >> "$SENTINEL_FILE"
EOF
chmod +x "$STUB_BIN/,note"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rm -rf "$TMP_HOME"; exit 1; }

export HOME="$TMP_HOME"
export PATH="$STUB_BIN:$PATH"
export CRONTAB_CAPTURE="$TMP_HOME/crontab_capture"
export SENTINEL_FILE="$TMP_HOME/sentinel"
touch "$TMP_HOME/.zshrc"

bash "$NOTE_DIR/install.sh" >/dev/null

[ -L "$TMP_HOME/bin/,note" ] || fail "~/bin/,note is not a symlink"
[ "$(readlink "$TMP_HOME/bin/,note")" = "$NOTE_DIR/,note" ] || fail "~/bin/,note points at the wrong target"
pass "~/bin/,note symlinked to \$NOTE_DIR/,note"

grep -q "git_auto_commit.sh" "$CRONTAB_CAPTURE" || fail "cron line not installed"
pass "cron line installed"

[ ! -f "$SENTINEL_FILE" ] || fail "install.sh executed \`,note\` via unintended command substitution"
pass "install.sh does not execute ,note as a side effect"

# run again: must not error, must not duplicate/break the symlink
bash "$NOTE_DIR/install.sh" >/dev/null
[ -L "$TMP_HOME/bin/,note" ] || fail "symlink broken after second install run"
pass "install.sh is idempotent"

rm -rf "$TMP_HOME"
echo "All tests passed."
