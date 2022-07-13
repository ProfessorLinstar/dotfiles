"
" VSCode Neovim Configuration
"

source ~/dotfiles/.config/nvim/nvimcore/plugins.vim

let mapleader =" "

nnoremap <tab> <cmd>call VSCodeCall("workbench.action.navigateEditorGroups")<CR>
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>
nnoremap <Leader>r <cmd>:noh<CR>
nnoremap <Leader>w <cmd>call VSCodeCall("workbench.action.files.save")<CR>
nnoremap <Leader>dq <cmd>call VSCodeCall("workbench.action.closeGroup")<CR>
nnoremap <Leader>dd <cmd>call VSCodeCall("workbench.action.closeActiveEditor")<CR>
nnoremap <Leader>/ <cmd>call VSCodeCall("editor.action.commentLine")<CR>
vnoremap <Leader>/ <esc><cmd>call VSCodeCallRange("editor.action.commentLine", getpos("'<")[1], getpos("'>")[1], 1)<CR>
