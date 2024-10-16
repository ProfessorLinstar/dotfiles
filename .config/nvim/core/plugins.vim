" Setup plugin manager
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'ggandor/leap.nvim'              " vim navigation
Plug 'tpope/vim-surround'             " Provides some shortcuts for delimiter manipulation
Plug 'tpope/vim-commentary'	          " Provides commenting
Plug 'vim-airline/vim-airline' 	      " Provides status bars
Plug 'vim-airline/vim-airline-themes' " Airline themes
Plug 'tpope/vim-obsession'            " Improve vim sessions functionality
Plug 'moll/vim-bbye'                  " More intelligent buffer deletion
Plug 'tpope/vim-fugitive'             " Git-integration for vim
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install' } " Markdown integration for neovim (requires yarn)
Plug 'folke/which-key.nvim'           " Keybinding hints
Plug 'akinsho/bufferline.nvim', { 'tag': '*' } " Buffer management
Plug 'kyazdani42/nvim-web-devicons'   " for coloured icons

call plug#end()

" lua plugin setup
lua << EOF
require("which-key").setup { win = {height = 8} }
  require("bufferline").setup {}
EOF

" vim-airline & vim-airline-themes
let g:airline#extensions#tabline#show_buffers = 0
let g:airline#extensions#tabline#enabled = 0
let g:airline#extensions#tabline#ignore_bufadd_pat = 'defx|gundo|nerd_tree|startify|tagbar|undotree|vimfiler'
let g:airline_powerline_fonts = 1

" markdown-preview.nvim
let g:mkdp_theme = 'dark'
let g:mkdp_auto_close = 0
