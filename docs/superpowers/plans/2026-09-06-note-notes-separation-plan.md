# Note/Notes Code-Data Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the `,note` tool's code (public `note` repo) from its data (private `notes` repo) across machines, with no duplicated code, a fixed path convention, safe multi-machine auto-commit, and Neovim/LazyVim integration.

**Architecture:** `note` (`~/Development/note`) is the sole source of code — script, install, cron, and a new Neovim Lua module. `notes` (`~/Documents/notes`) holds only data. Neovim's config gets thin symlinks into `note`, never a copy.

**Tech Stack:** Python 3 (stdlib only), Bash, Lua (Neovim), git, cron.

**Spec:** `/Users/andrew.parmar/Development/note/docs/superpowers/specs/2026-09-06-note-notes-separation-design.md`

## Global Constraints

- Code lives only in `~/Development/note` — `notes` never carries a copy of any script (no vendoring).
- Fixed paths, not env vars: code repo is always `~/Development/note`; data repo is always `~/Documents/notes`.
- Master-file model: one `notes.txt` + `personal_notes.txt`. No per-day dated files (dead code — delete, don't deprecate). No `REPO_DIR`/`rye_notes.txt` split.
- `rye_notes.txt` and the pre-cutover `notes.txt` stay in `~/Documents/notes` untouched as historical files.
- `git_auto_commit.sh` does `git pull --rebase` before commit/push; a real conflict must abort the script (not silently continue).
- `.gitignore` in `notes` covers `*.swp`/`*.swo`; the two currently-tracked swap files get untracked (kept on disk).
- Both `note` and `notes` have `git config user.email andrew.parmar@gmail.com` set locally (not global) — already applied on this machine, must be reproducible on others.
- `$EDITOR` is already `nvim`; no shell rc change needed for that.

---

### Task 1: Rewrite `,note` — fixed NOTES_DIR, drop dated-file mode

**Files:**
- Modify: `~/Development/note/,note`
- Create: `~/Development/note/tests/test_note.sh`

**Interfaces:**
- Produces: `NOTES_DIR` constant = `~/Documents/notes`; `get_filename_for_master_file() -> str`; `get_filename_for_personal_notes() -> str`. `get_filename_for_today()` is deleted — no later task depends on it.

- [ ] **Step 1: Write the test script (expected to fail against the current script)**

Create `~/Development/note/tests/test_note.sh`:

```bash
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
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
chmod +x ~/Development/note/tests/test_note.sh
~/Development/note/tests/test_note.sh
```

Expected: FAIL at the first assertion — `notes.txt` isn't at `$HOME/Documents/notes/notes.txt` (the current script still writes to `$HOME/notes/notes.txt`).

- [ ] **Step 3: Rewrite `,note`**

Replace `~/Development/note/,note` with:

```python
#!/usr/bin/env python3

import os
from datetime import datetime
import subprocess
import argparse

NOTES_DIR = os.path.join(os.path.expanduser("~"), "Documents", "notes")

def get_filename_for_master_file():
    """Returns the path for the master notes file."""
    os.makedirs(NOTES_DIR, exist_ok=True)
    filename = os.path.join(NOTES_DIR, "notes.txt")
    return filename

def get_filename_for_personal_notes():
    """
    Returns the path for the personal notes file.
    Modify the name or directory structure as desired.
    """
    os.makedirs(NOTES_DIR, exist_ok=True)
    personal_notes_file = os.path.join(NOTES_DIR, "personal_notes.txt")
    return personal_notes_file

def open_file_in_editor(filename, view_only=False):
    """
    Opens the specified file in Vim. If 'view_only' is True,
    open it in read-only mode. Otherwise, allow editing.
    """
    editor = os.getenv('EDITOR', 'vim')
    if view_only:
        # Open in read-only mode with Vim
        subprocess.call([editor, '+normal GzR', filename])
    else:
        subprocess.call([editor, "+normal GzRo", "+startinsert", filename])

def search_todo_items(filename):
    """
    Searches for lines containing the '†' character in the specified file.
    You can replace grep/ack as needed.
    """
    subprocess.call(['grep', '†', filename, '--color=always'])

def main():
    parser = argparse.ArgumentParser(description='Note-taking script with additional personal notes option.')
    parser.add_argument('-r', action='store_true', help='Open the note in read-only mode without adding a new entry.')
    parser.add_argument('--todo', action='store_true', help='Search for TODO items marked with † in the notes file.')
    parser.add_argument('--personal', action='store_true', help='Use the personal notes file instead of the master file.')
    args = parser.parse_args()

    # Decide which file to work with based on --personal
    if args.personal:
        filename = get_filename_for_personal_notes()
    else:
        filename = get_filename_for_master_file()

    file_exists = os.path.isfile(filename)

    # Handle TODO search
    if args.todo:
        search_todo_items(filename)
        return

    # If not read-only, append a new time-stamped note entry
    if not args.r:
        with open(filename, 'a') as file:
            if not file_exists:
                print(f"Creating new file: {filename}")
            date = datetime.now().date().strftime("%Y-%m-%d")
            current_time = datetime.now().strftime("%I:%M %p")
            day_of_week = datetime.now().strftime("%a").upper()
            entry = f"[{date} {day_of_week} {current_time}] - Note entry\n"
            # Add a blank line before new entry if the file already existed
            if file_exists:
                entry = "\n" + entry
            file.write(entry)

    # Finally, open the file (read-only or editable)
    open_file_in_editor(filename, view_only=args.r)

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test again and confirm it passes**

```bash
chmod +x ~/Development/note/,note
~/Development/note/tests/test_note.sh
```

Expected: all five `PASS` lines, then `All tests passed.`

- [ ] **Step 5: Commit**

```bash
cd ~/Development/note
git add ,note tests/test_note.sh
git commit -m "Fix NOTES_DIR to ~/Documents/notes, remove dead dated-file mode"
```

---

### Task 2: Rewrite `install.sh` — fixed paths, idempotent symlink, fix command-substitution bug

**Files:**
- Modify: `~/Development/note/install.sh`
- Create: `~/Development/note/tests/test_install.sh`

**Interfaces:**
- Consumes: `NOTE_DIR="$HOME/Development/note"` (this repo's own fixed location), `NOTES_DIR="$HOME/Documents/notes"` (Task 1's constant, mirrored in shell).
- Produces: `~/bin/,note` symlink, a crontab line `59 23 * * * $NOTE_DIR/git_auto_commit.sh >> $NOTES_DIR/git_auto_commit.log 2>&1`.

- [ ] **Step 1: Write the test script (expected to fail against the current install.sh)**

Create `~/Development/note/tests/test_install.sh`:

```bash
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
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
chmod +x ~/Development/note/tests/test_install.sh
~/Development/note/tests/test_install.sh
```

Expected: FAIL — either the symlink target check fails (current script hardcodes `~/notes/,note`) or the sentinel check fails (current script's final `echo` uses backticks around `` `,note` ``, which bash evaluates as command substitution).

- [ ] **Step 3: Rewrite `install.sh`**

Replace `~/Development/note/install.sh` with:

```bash
#!/bin/bash

NOTE_DIR="$HOME/Development/note"
NOTES_DIR="$HOME/Documents/notes"

# Set permissions for the scripts
chmod +x "$NOTE_DIR/,note"
chmod +x "$NOTE_DIR/git_auto_commit.sh"

# Symlink the script into ~/bin (idempotent - skip if already linked)
mkdir -p ~/bin
if [ ! -e ~/bin/,note ]; then
    ln -s "$NOTE_DIR/,note" ~/bin/,note
fi

# Ensure ~/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
fi

# Update the cron job
(crontab -l 2>/dev/null; echo "59 23 * * * $NOTE_DIR/git_auto_commit.sh >> $NOTES_DIR/git_auto_commit.log 2>&1") | crontab -

echo 'Installation complete. Use ,note to run the script.'
```

Note the last line now uses single quotes, so `,note` is printed literally instead of being run as a command substitution.

- [ ] **Step 4: Run the test again and confirm it passes**

```bash
~/Development/note/tests/test_install.sh
```

Expected: all `PASS` lines, then `All tests passed.`

- [ ] **Step 5: Commit**

```bash
cd ~/Development/note
git add install.sh tests/test_install.sh
git commit -m "Fix install.sh: idempotent symlink, fixed paths, fix command-substitution bug"
```

---

### Task 3: Rewrite `git_auto_commit.sh` — fixed NOTES_DIR, pull --rebase, abort on conflict

**Files:**
- Modify: `~/Development/note/git_auto_commit.sh`
- Create: `~/Development/note/tests/test_git_auto_commit.sh`

**Interfaces:**
- Consumes: `NOTES_DIR="$HOME/Documents/notes"` (same constant as Tasks 1–2).
- Produces: a script that exits non-zero and does not commit/push if `git pull --rebase` fails.

- [ ] **Step 1: Write the test script (expected to fail against the current script)**

Create `~/Development/note/tests/test_git_auto_commit.sh`:

```bash
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
echo "seed" > "$MACHINE_A/notes.txt"
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

# Machine B has a local, non-conflicting change and is now behind origin/main
echo "from machine B" >> "$HOME/Documents/notes/personal_notes.txt"

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/git_auto_commit.sh"
export HOME
bash "$SCRIPT" || fail "script exited non-zero on the non-conflicting rebase case"

git -C "$MACHINE_A" fetch -q origin
git -C "$MACHINE_A" log origin/main --oneline | grep -q "from A" || fail "machine A's commit missing from remote"
git -C "$HOME/Documents/notes" log --oneline | grep -q "from A" || fail "rebase did not pull machine A's commit"
[ -f "$HOME/Documents/notes/personal_notes.txt" ] || fail "machine B's own change is missing"
pass "non-conflicting multi-machine push succeeds via pull --rebase"

rm -rf "$TMP"
echo "All tests passed."
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
chmod +x ~/Development/note/tests/test_git_auto_commit.sh
~/Development/note/tests/test_git_auto_commit.sh
```

Expected: FAIL — the current script `cd`s to `/Users/$USER/notes`, not `$HOME/Documents/notes`, and has no `git pull --rebase`, so it can't see machine A's commit.

- [ ] **Step 3: Rewrite `git_auto_commit.sh`**

Replace `~/Development/note/git_auto_commit.sh` with:

```bash
#!/bin/bash

NOTES_DIR="$HOME/Documents/notes"

# Ensure the Git commands use the correct PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Navigate to the repository directory
cd "$NOTES_DIR" || exit 1

# Pull any changes from other machines first, to avoid a rejected push.
# A genuine conflict here must stop the script rather than compound it.
git pull --rebase || { echo "git pull --rebase failed, aborting"; exit 1; }

# Add all changes
git add -A

# Commit the changes with a timestamp
git commit -m "Automated commit on $(date '+%Y-%m-%d %H:%M:%S')"

# Push to the remote repository
git push origin main
```

- [ ] **Step 4: Run the test again and confirm it passes**

```bash
chmod +x ~/Development/note/git_auto_commit.sh
~/Development/note/tests/test_git_auto_commit.sh
```

Expected: `PASS` line, then `All tests passed.`

- [ ] **Step 5: Commit**

```bash
cd ~/Development/note
git add git_auto_commit.sh tests/test_git_auto_commit.sh
git commit -m "Fix git_auto_commit.sh path, add pull --rebase before commit/push"
```

---

### Task 4: Fix `notes` repo git hygiene — .gitignore, untrack swap files

**Files:**
- Create: `~/Development/notes/.gitignore` (repo is still at this path until Task 6 moves it)
- Modify (untrack only, files stay on disk): `~/Development/notes/.rye_notes.txt.swp`, `~/Development/notes/.rye_notes.txt.swo`

**Interfaces:**
- Produces: a `notes` repo where future `git add -A` (run nightly by Task 3's script) never picks up Vim swap files again.

- [ ] **Step 1: Confirm current tracked state (expected: both swap files tracked)**

```bash
cd ~/Development/notes
git ls-files | grep swp
git ls-files | grep swo
```

Expected: both files listed.

- [ ] **Step 2: Add `.gitignore` and untrack the swap files**

```bash
cd ~/Development/notes
printf '*.swp\n*.swo\n' > .gitignore
git rm --cached .rye_notes.txt.swp .rye_notes.txt.swo
```

- [ ] **Step 3: Verify the files are untracked but still present on disk**

```bash
cd ~/Development/notes
git ls-files | grep -c swp   # expect: 0
git ls-files | grep -c swo   # expect: 0
[ -f .rye_notes.txt.swp ] && [ -f .rye_notes.txt.swo ] && echo "files still on disk"
git status --porcelain       # expect: "D  .rye_notes.txt.swp", "D  .rye_notes.txt.swo", "?? .gitignore"
```

- [ ] **Step 4: Commit**

```bash
cd ~/Development/notes
git add .gitignore .rye_notes.txt.swp .rye_notes.txt.swo
git commit -m "Add .gitignore for Vim swap files, untrack existing ones"
```

---

### Task 5: Neovim/LazyVim integration

**Files:**
- Create: `~/Development/note/nvim/notes_tool.lua`
- Modify: `~/.config/nvim/lua/config/autocmds.lua` (currently an empty template — add one `require` line)
- Create (symlinks, not copies): `~/.config/nvim/syntax/notes.vim`, `~/.config/nvim/lua/notes_tool.lua`

**Interfaces:**
- Consumes: `notes.vim` (unchanged, already in `note` repo).
- Produces: `notes_tool.setup()`, `notes_tool.insert_timestamp()` — no other task depends on these.

- [ ] **Step 1: Write `nvim/notes_tool.lua`**

```bash
mkdir -p ~/Development/note/nvim
```

Create `~/Development/note/nvim/notes_tool.lua`:

```lua
local M = {}

local NOTES_DIR = vim.fn.expand("~/Documents/notes")

function M.insert_timestamp()
  local timestamp = os.date("[%Y-%m-%d %a %I:%M %p] - ")
  vim.api.nvim_put({ timestamp }, "c", true, true)
  vim.cmd("startinsert!")
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = {
      NOTES_DIR .. "/notes.txt",
      NOTES_DIR .. "/personal_notes.txt",
    },
    callback = function()
      vim.bo.filetype = "notes"
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "notes",
    callback = function(args)
      vim.keymap.set("n", "<leader>t", M.insert_timestamp, { buffer = args.buf, desc = "Insert note timestamp" })
    end,
  })
end

return M
```

- [ ] **Step 2: Write an isolated headless-Neovim test and confirm it fails (module doesn't exist yet on the runtimepath)**

Create `~/Development/note/tests/test_notes_tool.sh`:

```bash
#!/bin/bash
set -euo pipefail

NOTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
mkdir -p "$TMP/Documents/notes"
export HOME="$TMP"

nvim --headless --clean \
  -c "lua package.path = package.path .. ';${NOTE_DIR}/nvim/?.lua'" \
  -c "lua require('notes_tool').setup()" \
  -c "edit ${TMP}/Documents/notes/notes.txt" \
  -c "lua assert(vim.bo.filetype == 'notes', 'filetype not set: ' .. tostring(vim.bo.filetype))" \
  -c "lua require('notes_tool').insert_timestamp()" \
  -c "lua local l = vim.api.nvim_buf_get_lines(0,0,1,false)[1]; assert(l and l:match('^%[%d%d%d%d%-%d%d%-%d%d'), 'timestamp not inserted: ' .. tostring(l))" \
  -c "qa!"

echo "All tests passed."
rm -rf "$TMP"
```

```bash
chmod +x ~/Development/note/tests/test_notes_tool.sh
~/Development/note/tests/test_notes_tool.sh
```

Expected at this point: this should already PASS, since Step 1 already wrote the module — this step exists to lock in the isolated-test harness before wiring it into the real config. If it fails, fix `notes_tool.lua` before proceeding.

- [ ] **Step 3: Wire it into the real LazyVim config**

```bash
ln -s ~/Development/note/notes.vim ~/.config/nvim/syntax/notes.vim
ln -s ~/Development/note/nvim/notes_tool.lua ~/.config/nvim/lua/notes_tool.lua
```

Append to `~/.config/nvim/lua/config/autocmds.lua` (currently just the LazyVim template comments):

```lua
require("notes_tool").setup()
```

- [ ] **Step 4: Confirm the real config picks it up**

```bash
TMP=$(mktemp -d)
mkdir -p "$TMP/Documents/notes"
HOME="$TMP" nvim --headless \
  -c "edit ${TMP}/Documents/notes/notes.txt" \
  -c "lua assert(vim.bo.filetype == 'notes', 'filetype not set via real config: ' .. tostring(vim.bo.filetype))" \
  -c "qa!"
echo "real config OK"
rm -rf "$TMP"
```

Expected: `real config OK`, no assertion error.

- [ ] **Step 5: Commit (note repo only — `~/.config/nvim` is a separate, already-tracked dotfiles location and is not part of this plan's commits)**

```bash
cd ~/Development/note
git add nvim/notes_tool.lua tests/test_notes_tool.sh notes.vim
git commit -m "Add Neovim integration module for notes filetype + timestamp keymap"
```

---

### Task 6: Apply the real per-machine setup

**Files:** none (system state only — directory move, symlinks, cron, git config)

**Interfaces:**
- Consumes: Tasks 1–5's finished, tested code.
- Produces: the live setup on this machine.

- [ ] **Step 1: Check for uncommitted work before moving anything**

```bash
cd ~/Development/notes && git status
```

Expected: clean (already verified earlier in this project, but re-check immediately before the move).

- [ ] **Step 2: Move the data repo**

```bash
mv ~/Development/notes ~/Documents/notes
```

- [ ] **Step 3: Set git identity on both repos (idempotent — already applied once, safe to re-run)**

```bash
cd ~/Development/note && git config user.email andrew.parmar@gmail.com
cd ~/Documents/notes && git config user.email andrew.parmar@gmail.com
```

- [ ] **Step 4: Run the real install**

```bash
bash ~/Development/note/install.sh
```

- [ ] **Step 5: Verify the live symlink and crontab**

```bash
readlink ~/bin/,note   # expect: /Users/andrew.parmar/Development/note/,note
crontab -l | grep git_auto_commit
```

---

### Task 7: End-to-end acceptance verification

**Files:** none

- [ ] **Step 1: Master notes flow**

```bash
,note
```
Confirm: opens `~/Documents/notes/notes.txt` in `nvim`, cursor at end, insert mode, `NoteDate`/`TodoItem`/`CompletedItem`/`BulletItem` highlighting visible, `:set filetype?` reports `notes`.

- [ ] **Step 2: Read-only mode**

```bash
,note -r
```
Confirm: opens read-only, no new timestamped entry was appended.

- [ ] **Step 3: TODO search**

```bash
,note --todo
```
Confirm: greps `†`-marked lines from `notes.txt`.

- [ ] **Step 4: Timestamp keymap**

Open `~/Documents/notes/notes.txt` in `nvim`, press `<leader>t` — confirm a formatted timestamp is inserted at the cursor and insert mode is entered.

- [ ] **Step 5: rye_notes.txt is untouched**

```bash
shasum ~/Documents/notes/rye_notes.txt
```
Record the checksum; re-check after Step 6 below — must be identical (nothing writes to it anymore).

- [ ] **Step 6: Manual auto-commit run against the real private repo**

```bash
~/Development/note/git_auto_commit.sh
cd ~/Documents/notes && git log -1 --stat
```
Confirm: `git pull --rebase` + commit + push succeed cleanly, the diff contains no swap files, and `rye_notes.txt`'s checksum from Step 5 is unchanged.

- [ ] **Step 7: Confirm cron is live for tonight**

```bash
crontab -l
```
Confirm the line points at `~/Development/note/git_auto_commit.sh` and logs to `~/Documents/notes/git_auto_commit.log`.
