" Setup plugin manager
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'justinmk/vim-sneak'             " Two-letter vim navigation
Plug 'tpope/vim-surround'             " Provides some shortcuts for delimiter manipulation
Plug 'tpope/vim-commentary'	          " Provides commenting
Plug 'vim-airline/vim-airline' 	      " Provides status bars
Plug 'vim-airline/vim-airline-themes' " Airline themes
Plug 'tpope/vim-obsession'            " Improve vim sessions functionality
Plug 'moll/vim-bbye'                  " More intelligent buffer deletion
Plug 'tpope/vim-fugitive'             " Git-integration for vim

call plug#end()

let g:airline#extensions#tabline#show_buffers = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
