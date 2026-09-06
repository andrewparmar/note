#!/bin/bash

NOTE_DIR="$HOME/Development/note"
NOTES_DIR="$HOME/Documents/notes"

# Set permissions for the scripts
chmod +x "$NOTE_DIR/,note"
chmod +x "$NOTE_DIR/git_auto_commit.sh"

# Symlink the script into ~/bin (self-healing: repairs a stale, dangling,
# or wrong-target symlink left over from migrating layouts)
mkdir -p ~/bin
ln -sfn "$NOTE_DIR/,note" ~/bin/,note

# Ensure ~/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
fi

# Update the cron job (log lives outside the private notes repo so two
# machines appending to it don't collide with git_auto_commit.sh's own commits)
mkdir -p "$HOME/Library/Logs"
(crontab -l 2>/dev/null; echo "59 23 * * * $NOTE_DIR/git_auto_commit.sh >> $HOME/Library/Logs/note-auto-commit.log 2>&1") | crontab -

echo 'Installation complete. Use ,note to run the script.'

