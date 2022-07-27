nnoremap <Leader>dq <cmd>q<CR>
nnoremap <Leader>dd <cmd>bp \| bd #<CR>
nnoremap <Leader>da <cmd>wqa<CR>
nnoremap <Leader>dr <cmd>set all& \| wqa <CR>
nnoremap <Leader>df <cmd>earlier 1f<CR>
nnoremap <Leader>dF <cmd>later 1f<CR>

nnoremap <Leader>ap <cmd>let @+=expand('%:p:h') \| echo @+<CR>
nnoremap <Leader>aP <cmd>let @+=expand('%:p') \| echo @+<CR>
nnoremap <Leader>ae <cmd>OpenDirectory<CR>
nnoremap <Leader>ad <cmd>OpenFile<CR>
nnoremap <Leader>af <cmd>if v:count \| let &shiftwidth=v:count \| let &tabstop=v:count \| endif<CR>
nnoremap <Leader>aw <cmd>TrimTrailingWhitespace<CR>
nnoremap <Leader>at <cmd>terminal<CR>

nnoremap <Leader>bl <cmd>:buffers<CR>

nnoremap <Leader>r <cmd>noh<CR>
nnoremap <Leader>w <cmd>w<CR>
nnoremap <Leader>t <cmd>JumpToClipboard<CR>
nnoremap <Leader>c <cmd>CdToFile<CR>
nnoremap <Leader>C <cmd>CdToSession<CR>
nnoremap <Leader>q <cmd>qa<CR>
nnoremap <Leader>v <cmd>tab split<CR>
nnoremap <Leader>x <cmd>tabclose<CR>
nnoremap <Leader>z <C-w>\|
nnoremap <Leader>Z <C-w>=

nnoremap <C-j> <cmd>bn<cr>
nnoremap <C-k> <cmd>bp<cr>
nnoremap <C-h> <cmd>tabp<cr>
nnoremap <C-l> <cmd>tabn<cr>
nnoremap <S-tab> <C-w>W
nnoremap <tab> <C-w>w
nnoremap <M-i> <C-i>
nnoremap <expr> j v:count ? ("m'" . v:count) . 'j' : 'gj'
nnoremap <expr> k v:count ? ("m'" . v:count) . 'k' : 'gk'
nnoremap ]n /\(<<<<<<<\\|=======\\|>>>>>>>\)<CR>
nnoremap [n ?\(<<<<<<<\\|=======\\|>>>>>>>\)<CR>

vnoremap // y/\V<C-R>=escape(@",'/\')->substitute('\n','\\n','g')<CR><CR>
nnoremap gt `[v`]

inoremap <M-o> <CR>
nnoremap <C-f> :<C-f>
nnoremap - @:
nnoremap _ @@
vnoremap _ g_
onoremap _ g_

noremap <M-q> <cmd>ToggleSyntax<CR>
noremap <M-p> "0p
noremap <M-P> "0P

cnoremap <M-f> <C-right>
cnoremap <M-b> <C-left>
cnoremap <C-a> <C-b>
cnoremap <C-d> <Del>

tnoremap <ESC> <C-\><C-n>
tnoremap <expr> <C-R> '<C-\><C-N>"'.nr2char(getchar()).'pi'
