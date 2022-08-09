" Core mappings
command! JumpToClipboard if @+ =~# "^\\d\\+$" | to @+ | echo "Jumped to line " . @+ | else | echohl WarningMsg | echo "Clipboard is NaN." | echohl None | endif
command! CdToFile cd %:p:h | pwd
command! CdToSession execute "cd" fnameescape("/" . split(v:this_session, "/")[:-2]->join("/") ) | pwd
command! ToggleSyntax if exists("g:syntax_on") | syntax off | else | syntax enable | endif
command! TrimTrailingWhitespace execute "normal! m'" | let s:search=@/ | %s/\s\+$//ge | let @/=s:search | noh | normal! `'
command! Scratch execute "e " . tempname() | setl buftype=nofile nobuflisted

" GUI interactions
let s:default = 'xdg-open'
command! OpenDirectory call system( s:default . ' "' . expand('%:p:h') . '" &')
command! OpenFile call system( s:default . ' "' . expand('%:p') . '" &')

" Debugging
command! EchoSyntaxGroups echo 'hi<' . synID(line('.'),col('.'),1)->synIDattr('name') . '> trans<' .
                                     \ synID(line('.'),col('.'),0)->synIDattr('name') . '> lo<' .
                                     \ synID(line('.'),col('.'),1)->synIDtrans()->synIDattr('name') . '>'
