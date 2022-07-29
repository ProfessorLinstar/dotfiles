# Linstar's dotfiles
This repository contains configuration files for my linux workspace. The following shows a tree of the 'dotfiles' repository, along with details describing the role of each file.

```
. (dotfiles)
├── .bash_profile                    --- bash login interactive startup file
├── .bashrc                          --- bash non-login interactive startup file
├── .config                          ---
│   ├── alacritty                    ---
│   │   └── alacritty.yml            --- Alacritty configuration file
│   ├── dconf                        ---
│   │   └── manjaro.dconf            --- Result of 'dconf dump /' in Manjaro
│   ├── lvim                         ---
│   │   ├── config.lua               --- Lunarvim main configuration file
│   │   ├── lua                      ---
│   │   │   └── core                 ---
│   │   │       ├── mappings.lua     --- Lunarvim-specific mappings
│   │   │       └── options.lua      --- Lunarvim options and plugins
│   │   └── spell                    --- Vim spelling files
│   │       ├── en.utf-8.add         ---
│   │       └── en.utf-8.add.spl     ---
│   ├── nvim                         ---
│   │   ├── core                     --- Neovim configuration files
│   │   │   ├── autocommands.vim     --- Global autocommands
│   │   │   ├── commands.vim         ---
│   │   │   ├── filetypes.vim        --- Filetype-specific options
│   │   │   ├── mappings.vim         ---
│   │   │   ├── options.vim          ---
│   │   │   ├── plugins.vim          ---
│   │   │   └── plugmaps.vim         --- Mappings for neovim/lunarvim plugins
│   │   ├── extensions               ---
│   │   │   └── vscode.vim           --- Configuration file for neovim in vscode
│   │   ├── init.vim                 --- Neovim main configuration file (sources 'core')
│   │   └── snippets                 ---
│   └── okular                       ---
│       └── default                  ---
├── .profile                         --- sh-compatible login startup file
├── README.md                        --- dotfiles overview
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
├── .vimrc                           --- Vim main configuration file (deprecated)
├── .zprofile                        --- zshell login startup file
└── .zshrc                           --- zshell interactive startup file
```

## Manual Fixes
I try to avoid modifying plugin files directly, but the following have been changed to suit my needs.

 - **~/.tmux/plugins/tmux-resurrect/strategies/nvim_session.sh**: `nvim -S` changed to `vis`
   - `vis` attempts to execute `vi -S` in the closest parent directory that contains a `Session.vim` file. When tmux is resurrected, the cwd of the pane may not be the same as the Session.vim file, so `nvim -S` may not work.
 - **~/.local/share/lunarvim/site/pack/packer/start/vimtex/autoload/vimtex/syntax/core.vim**: `48-57` removed from `set iskeyword`, so `nvim -S` may not work.
   - Prevents numbers from being recognized as keywords in LaTeX macros when determining syntax highlighting.
 - 

## Shell Startup Files
The key things to know regarding shell startup files are the following. By default,

 - .bash_profile is used for login bash shells
 - .bashrc is used for non-login interactive bash shells

for bash, and

 - .zprofile is used for login zsh shells
 - .zshrc is used for interactive zsh shells

for zsh. Additionally, if .bash_profile exists, then .profile will not be executed; a similar behavior occurs for zsh. Environment variables shared across different shells should be in the global .profile file (e.g. $PATH). Shell-specific settings should be left in the respective .zshrc and .bashrc files. In general, it is nice to source both the profile and rc files for bash and zsh whenever running an interactive shell. To do so, we have the following dependency structure. For zsh:

 - .zshrc &rarr; .zprofile (if not login).

And for bash:

 - .bashrc &rarr; .bash_profile (if not login)
 - .bash_profile &rarr; .bashrc (if login and interactive).

And finally, in general, shell-specific profile files source the global .profile file:

 - .{shell-profile} &rarr; .profile
