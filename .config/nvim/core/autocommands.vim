augroup system_yank " Yank to system clipboard with y register
  au!
  autocmd TextyankPost * if v:event.regname ==# 'y' | let @+=@y | endif
augroup end

augroup accurate_syntax_sync " Make syntax highlighting more accurate
  au!
  autocmd BufRead,BufNewFile * syntax sync fromstart
augroup end
