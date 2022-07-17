# Linstar's dotfiles
This repository contains configuration files for my linux workspace. The following shows a tree of the 'dotfiles' repository, along with details describing the role of each file.

```
. (dotfiles)
├── .bashrc                          --- bash configuration file
├── .config                          --- 
│   ├── alacritty                    --- 
│   │   └── alacritty.yml            --- Alacritty configuration file
│   ├── lvim                         --- 
│   │   ├── config.lua               --- 
│   │   ├── lua                      --- 
│   │   │   └── core                 --- 
│   │   │       ├── mappings.lua     --- Lunarvim-specific mappings
│   │   │       └── options.lua      --- Lunarvim options and plugins 
│   │   └── spell                    --- Vim spelling files
│   │       ├── en.utf-8.add         --- 
│   │       └── en.utf-8.add.spl     --- 
│   └── nvim                         --- 
│       ├── core                     --- Neovim configuration files
│       │   ├── autocommands.vim     --- 
│       │   ├── commands.vim         --- 
│       │   ├── mappings.vim         --- 
│       │   ├── options.vim          --- 
│       │   ├── plugins.vim          --- 
│       │   ├── plugmaps.vim         --- Mappings for neovim/lunarvim plugins
│       │   └── vscode.vim           --- Configuration file for neovim in vscode
│       └── init.vim                 --- Neovim main configuration file (sources 'core')
├── .profile                         --- 
├── root                             --- 
│   ├── etc                          --- 
│   │   ├── logid.cfg                --- Logid configuration file for Logitech peripherals
│   │   ├── modprobe.d               --- 
│   │   │   └── hid_apple.conf       --- NuPhy Air75 fix for function keys
│   │   └── vconsole.conf            --- Linux virtual console configuration file
│   └── usr                          --- 
│       ├── local                    --- 
│       │   └── bin                  --- 
│       │       └── vis              --- "vi -S" in closest parent directory
│       └── share                    --- 
│           └── kbd                  --- 
│               └── keymaps          --- 
│                   └── us-caps.map  --- Keymap for linux console remapping caps to escape
├── .tmux.conf                       --- tmux configuration file
├── .vimrc                           --- Vim configuration file (deprecated)
└── .zshrc                           --- zshell configuration file
```
