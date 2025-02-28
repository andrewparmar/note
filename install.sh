#!/bin/bash

# Set permissions for the note taker script
chmod +x ,note

# Move the script to ~/bin/note
mkdir -p ~/bin
ln -s ~/notes/,note ~/bin/,note

# Ensure ~/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
fi

# Update the cron job
(crontab -l 2>/dev/null; echo "59 23 * * * $HOME/notes/git_auto_commit.sh >> $HOME/notes/git_auto_commit.log 2>&1") | crontab -

echo "Installation complete. Use `,note` to run the script."

