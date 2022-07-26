augroup colorscheme_modifications
  au!
  " Custom color scheme modifications
  autocmd ColorScheme * highlight! link texCmdGreek Function
  autocmd ColorScheme * highlight! link texMathDelim Delimiter 
  autocmd ColorScheme * highlight! link texMathSymbol String " Remove '48-57' from 'iskeyword' in vimtex/syntax/core.vim
augroup end

augroup filetype_indentation
  au!
  autocmd FileType cs,py set tabstop=4 | set shiftwidth=4
augroup end
