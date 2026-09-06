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

