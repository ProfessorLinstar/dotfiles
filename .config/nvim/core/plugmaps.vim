" moll/vim-bbye: intelligent buffer deletion (overrides <Leader>dd)
nnoremap <Leader>dd <cmd>Bdelete<CR>

" justinmk/vim-sneak: Prevent vim-sneak from stealing s key
noremap ' <Plug>Sneak_s
noremap <M-'> <Plug>Sneak_S

" tpope/vim-obsession: shortcut for editing Sessionx.vim file
nnoremap <Leader>ax <cmd>if v:this_session != "" \| execute "e " . substitute(g:this_obsession, "Session.vim", "Sessionx.vim", "") \| endif<CR>

" lervag/vimtex: Prevent vimtex from stealing ts chord
nnoremap ts<Space> ts

" tpope/vim-commentary: Mappings for toggling comments
nmap <Leader>/ gcc
vmap <Leader>/ gc

" tpope/vim-fugitive: Vim diff shorcuts
nnoremap <Leader>gt <cmd>Gdiffsplit!<CR>
nnoremap <Leader>g2 <cmd>diffget //2<CR>
nnoremap <Leader>g3 <cmd>diffget //3<CR>

" Markdown preview
nnoremap <Leader>am <cmd>MarkdownPreview<CR>
nnoremap <Leader>aM <cmd>MarkdownPreviewStop<CR>
