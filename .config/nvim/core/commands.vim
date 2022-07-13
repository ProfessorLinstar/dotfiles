let s:explorer = has('unix') ? 'xdg-open' : 'explorer'

" Open current working directory in file explorer
command! OpenInExplorer call system( s:explorer . ' "' . expand('%:p:h') . '" &')
