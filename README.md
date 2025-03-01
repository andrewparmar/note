# note
Simple note taking tool.

# Requirements
- python 3
- vim

# Installation
`bash install.sh`

## .vimrc

Add the following to .vimrc

```
" Associate notes.txt with the 'notes' filetype
"autocmd BufRead,BufNewFile notes.txt setfiletype notes
autocmd BufRead,BufNewFile notes.txt setlocal filetype=notes | doautocmd Syntax

function! InsertTimestamp()
    let l:timestamp = strftime("[%Y-%m-%d %a %I:%M %p] - ")
    execute 'normal! i' . l:timestamp
endfunction

" Optional: Map a key for quick insertion (e.g., <leader>t)
nnoremap <leader>t :call InsertTimestamp()<CR>
```

## vim syntax file.
Move the syntax file to your vim config directory. Depending how how vim was installed this location 
could vary.

# Usage
> ,note

# Why the ,?
Typing ,<tab> is a quick way to see all your personal tools. It's just a personal preference, and
could be replaced with any other leader key.


