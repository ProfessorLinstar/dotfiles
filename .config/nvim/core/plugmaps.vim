" moll/vim-bbye: intelligent buffer deletion
nnoremap <Leader>dd <cmd>Bdelete<CR>

" justinmk/vim-sneak: Prevent vim-sneak from stealing s key
noremap ' <Plug>Sneak_s
noremap <M-'> <Plug>Sneak_S

" lervag/vimtex: Prevent vimtex from stealing ts chord
nnoremap ts<Space> ts

" tpope/vim-commentary: Mappings for toggling comments
nmap <Leader>/ gcc
vmap <Leader>/ gc

" tpope/vim-fugitive: Vim diff shorcuts
nnoremap <Leader>gt <cmd>Gdiffsplit!<CR>
nnoremap <Leader>g2 <cmd>diffget //2<CR>
nnoremap <Leader>g3 <cmd>diffget //3<CR>
