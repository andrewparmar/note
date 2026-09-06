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
