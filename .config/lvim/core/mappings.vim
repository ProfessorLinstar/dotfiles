nnoremap <Leader>j <cmd>BufferLinePick<CR>
nnoremap <Leader>; <cmd>if luaeval("vim.bo.ft") != "alpha" \| tab split \| endif \| execute "Alpha" \| cd %:p:h<CR>

" Restore functionality of HML
noremap H H
noremap L L
