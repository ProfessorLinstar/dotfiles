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
      return ":b /" . l:matches[0] . "\<CR>"
    elseif len(l:matches) == 0
      return ":\<CR>"
    endif
  endfor

  return ":b /" . l:search
endfunction

" returns expression for editing registers. Cleans up bad characters in macro
" (e.g. tabs, single-quotes, null characters, and terminating carriage returns)
function! EditMacro()
  let l:reg = nr2char(getchar())
	let l:expandtab = &expandtab
  return  ":set noexpandtab\<CR>"                                        .
				\ 'ilet @' . l:reg . "='\<C-r>\<C-r>=getreg('" . l:reg . "')"    .
        \ "->substitute('''', '''''', 'g')\<CR>'\<ESC>"                  .
        \ ":s/\\(\<C-v>\<CR>\\)\\@<='$/\<C-v>\<C-q>\<C-v>\<C-q>'/e\<CR>" .
        \ ":s/\<C-v>000/\<C-v>\<C-q>j/ge\<CR>"                           .
        \ ":let &expandtab = " . l:expandtab . "\<CR>$i"
endfunction
