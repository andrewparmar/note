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
