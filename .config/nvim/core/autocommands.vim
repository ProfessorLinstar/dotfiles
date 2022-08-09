" Yank to system clipboard with y register
augroup system_yank
  au!
  autocmd TextyankPost * if v:event.regname ==# 'y' | let @+=@y | endif
augroup end

" Make syntax highlighting more accurate
augroup accurate_syntax_sync
  au!
  autocmd BufRead,BufNewFile * syntax sync fromstart
augroup end
