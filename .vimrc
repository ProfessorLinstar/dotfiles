source ~/dotfiles/.config/nvim/core/options.vim
source ~/dotfiles/.config/nvim/core/commands.vim
source ~/dotfiles/.config/nvim/core/autocommands.vim
source ~/dotfiles/.config/nvim/core/mappings.vim

if !isdirectory($HOME."/.vim")
      call mkdir($HOME."/.vim", "", 0770)
endif
if !isdirectory($HOME."/.vim/undodir")
      call mkdir($HOME."/.vim/undodir", "", 0700)
endif
set undodir=~/.vim/undodir
