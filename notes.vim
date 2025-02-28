" Syntax definitions for notes files

if exists("b:current_syntax")
  finish
endif

" Match text inside square brackets and assign it to the NoteDate group; set
" to red
syntax match NoteDate /^\[[^]]*\]/
highlight NoteDate ctermfg=LightBlue guifg=#add8e6

" Match lines starting with '-†' and assign to 'TodoItem' group
syntax match TodoItem /^\s*-†.*$/
highlight TodoItem ctermfg=LightRed guifg=#ff7373

" Match lines with optional whitespace before '-√' and assign to 'CompletedItem' group
syntax match CompletedItem /^\s*-√.*$/
highlight CompletedItem ctermfg=LightGreen guifg=#90ee90

" Match lines with optional whitespace before '-•' and assign to 'BulletItem' group
syntax match BulletItem /^\s*-•.*$/
highlight BulletItem ctermfg=Yellow guifg=#ffff00

let b:current_syntax = "notes"
