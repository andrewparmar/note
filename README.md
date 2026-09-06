# note
Simple note taking tool.

# Requirements
- python 3
- Neovim (or Vim) — `$EDITOR` should point at your editor of choice

# Installation
`bash install.sh`

This symlinks `,note` into `~/bin`, sets up a nightly cron job that
auto-commits and pushes your private notes repo, and expects your notes
data to live in `~/Documents/notes` (a separate, private git repo — this
repo only holds the tool's code).

## Neovim / LazyVim integration

Symlink the syntax file and the Lua module into your Neovim config, then
require the module from your `autocmds.lua`:

```
ln -s "$(pwd)/notes.vim" ~/.config/nvim/syntax/notes.vim
ln -s "$(pwd)/nvim/notes_tool.lua" ~/.config/nvim/lua/notes_tool.lua
```

Add to `~/.config/nvim/lua/config/autocmds.lua`:
```lua
require("notes_tool").setup()
```

This gives you `notes` filetype syntax highlighting on `~/Documents/notes/notes.txt`
and `~/Documents/notes/personal_notes.txt`, plus a buffer-local `<leader>t`
keymap that inserts a formatted timestamp.

# Usage
> ,note

# Why the ,?
Typing ,<tab> is a quick way to see all your personal tools. It's just a personal preference, and
could be replaced with any other leader key.
