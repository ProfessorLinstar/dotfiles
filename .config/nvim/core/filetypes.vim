augroup tex " Custom color scheme modifications
  au!
  autocmd ColorScheme * highlight! link texCmdGreek Function
  autocmd ColorScheme * highlight! link texMathDelim Delimiter 
  autocmd ColorScheme * highlight! link texMathSymbol String " Remove '48-57' from 'iskeyword' in vimtex/syntax/core.vim
augroup end
