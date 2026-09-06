#!/bin/bash
set -euo pipefail

NOTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
mkdir -p "$TMP/Documents/notes"
export HOME="$TMP"

# Mirror the real install layout (repo's notes.vim symlinked into an
# rtp-registered syntax/ dir) so this isolated test actually exercises
# syntax autoloading, not just the Lua module in isolation.
mkdir -p "$TMP/rtp/syntax"
ln -s "$NOTE_DIR/notes.vim" "$TMP/rtp/syntax/notes.vim"

nvim --headless --clean \
  -c "set rtp+=${TMP}/rtp" \
  -c "lua package.path = package.path .. ';${NOTE_DIR}/nvim/?.lua'" \
  -c "lua require('notes_tool').setup()" \
  -c "edit ${TMP}/Documents/notes/notes.txt" \
  -c "lua assert(vim.bo.filetype == 'notes', 'filetype not set: ' .. tostring(vim.bo.filetype))" \
  -c "lua vim.wait(500, function() return vim.b.current_syntax == 'notes' end); assert(vim.b.current_syntax == 'notes', 'syntax not loaded (filetype set but highlighting never fired): ' .. tostring(vim.b.current_syntax))" \
  -c "lua vim.api.nvim_buf_set_lines(0, 0, -1, false, {'-√ completed item'}); local id = vim.fn.synID(1, 3, 1); assert(vim.fn.synIDattr(id, 'name') == 'CompletedItem', 'CompletedItem highlight group not applied: ' .. vim.fn.synIDattr(id, 'name'))" \
  -c "lua vim.api.nvim_buf_set_lines(0, 0, -1, false, {''}); vim.api.nvim_win_set_cursor(0, {1, 0}); require('notes_tool').insert_timestamp()" \
  -c "lua local l = vim.api.nvim_buf_get_lines(0,0,1,false)[1]; assert(l and l:match('^%[%d%d%d%d%-%d%d%-%d%d'), 'timestamp not inserted: ' .. tostring(l))" \
  -c "qa!"

echo "All tests passed."
rm -rf "$TMP"
