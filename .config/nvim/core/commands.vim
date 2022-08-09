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

" Jump to buffer by name
function! BufferJump()
  let l:search = ""
  let l:bufs = map(filter(range(1, bufnr('$')), 'buflisted(v:val)'), 'fnamemodify(bufname(v:val), ":t")')

  for i in [1, 2, 3]
    let l:search = l:search . nr2char(getchar())
    let l:matches = []

    for fname in l:bufs
      if fname =~ "^" . l:search . ".*" | call add(l:matches, fname) | endif
    endfor

    if len(l:matches) == 1
      return "b /" . l:matches[0] . "\<CR>"
    elseif len(l:matches) == 0
      return "\<CR>"
    endif
  endfor

  return "b /" . l:search
endfunction
