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

" tpope/vim-fugitive: git shortcuts
nnoremap go <cmd>Git<CR><C-w>o
nnoremap <Leader>gt <cmd>Gvdiffsplit!<CR>
nnoremap <Leader>g2 <cmd>diffget //2<CR>
nnoremap <Leader>g3 <cmd>diffget //3<CR>

" iamcco/markdown-preview.nvim: preview shortcuts
nnoremap <Leader>am <cmd>MarkdownPreview<CR>
nnoremap <Leader>aM <cmd>MarkdownPreviewStop<CR>

" akinsho/bufferline.nvim: buffer close shortcuts
nnoremap <Leader>bl <cmd>BufferLineCloseLeft<CR>
nnoremap <Leader>br <cmd>BufferLineCloseRight<CR>
nnoremap <Leader>bo <cmd>BufferLineCloseOthers<CR>
