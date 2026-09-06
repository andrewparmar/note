#!/bin/bash

NOTES_DIR="$HOME/Documents/notes"

# Ensure the Git commands use the correct PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Navigate to the repository directory
cd "$NOTES_DIR" || exit 1

# Add all changes
git add -A

# Commit the changes with a timestamp
git commit -m "Automated commit on $(date '+%Y-%m-%d %H:%M:%S')"

# Pull any changes from other machines after committing locally, so a
# real conflict aborts cleanly instead of blocking on the local diff.
git pull --rebase || { git rebase --abort 2>/dev/null; echo "git pull --rebase failed, aborting" >&2; exit 1; }

# Push to the remote repository
git push origin main
