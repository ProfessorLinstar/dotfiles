" moll/vim-bbye: intelligent buffer deletion (overrides <Leader>dd)
nnoremap <Leader>dd <cmd>Bdelete<CR>

" ggandor/leap.nvim: Use '/M-' as the default jump keys
noremap ' <Plug>(leap-forward-to)
noremap <M-'> <Plug>(leap-backward-to)

" tpope/vim-obsession: shortcut for editing Sessionx.vim file
nnoremap <Leader>ax <cmd>if v:this_session != "" \| execute "e " . substitute(g:this_obsession, "Session.vim", "Sessionx.vim", "") \| endif<CR>

" lervag/vimtex: Prevent vimtex from stealing ts chord
nnoremap ts<Space> ts

" lervag/vimtex: Jump to clipboard line number
nnoremap \t <cmd>JumpToClipboard<CR>

" tpope/vim-commentary: Mappings for toggling comments
nmap <Leader>/ gcc
vmap <Leader>/ gc

" tpope/vim-fugitive: Vim diff shorcuts
nnoremap <Leader>gt <cmd>Gvdiffsplit!<CR>
nnoremap <Leader>g2 <cmd>diffget //2<CR>
nnoremap <Leader>g3 <cmd>diffget //3<CR>

" Markdown preview
nnoremap <Leader>am <cmd>MarkdownPreview<CR>
nnoremap <Leader>aM <cmd>MarkdownPreviewStop<CR>
