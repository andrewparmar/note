#!/bin/bash

# Navigate to the repository directory
cd /Users/$USER/notes

# Ensure the Git commands use the correct PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Add all changes
git add -A

# Commit the changes with a timestamp
git commit -m "Automated commit on $(date '+%Y-%m-%d %H:%M:%S')"

# Push to the remote repository
git push origin main
