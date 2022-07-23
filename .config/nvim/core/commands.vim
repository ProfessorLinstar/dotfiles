let s:default = 'xdg-open'

" Open current working directory in file explorer
command! OpenDirectory call system( s:default . ' "' . expand('%:p:h') . '" &')
command! OpenFile call system( s:default . ' "' . expand('%:p') . '" &')
