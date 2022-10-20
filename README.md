# Linstar's dotfiles
This repository contains configuration files for my linux workspace. The following shows a tree of the 'dotfiles' repository, along with details describing the role of each file.

```
. (dotfiles)
├── .bash_profile                    --- bash login interactive startup file
├── .bashrc                          --- bash non-login interactive startup file
├── .config                          ---
│   ├── alacritty                    ---
│   │   └── alacritty.yml            --- alacritty terminal emulatro configuration file
│   ├── lvim                         ---
│   │   ├── config.lua               --- Lunarvim main configuration file
│   │   ├── lua                      ---
│   │   │   └── core                 ---
│   │   │       ├── mappings.lua     --- Lunarvim-specific mappings
│   │   │       └── options.lua      --- Lunarvim options and plugins
│   │   └── spell                    --- Lunarvim spelling files
│   │       ├── en.utf-8.add         ---
│   │       └── en.utf-8.add.spl     ---
│   ├── nvim                         ---
│   │   ├── core                     ---
│   │   │   ├── autocommands.vim     --- Global autocommands
│   │   │   ├── commands.vim         ---
│   │   │   ├── filetypes.vim        --- Filetype specific settings and autocommands
│   │   │   ├── mappings.vim         ---
│   │   │   ├── options.vim          ---
│   │   │   ├── plugins.vim          ---
│   │   │   └── plugmaps.vim         --- Mappings for neovim/lunarvim plugins
│   │   └── init.vim                 --- Neovim main configuration file (sources 'core')
│   └── yapf                         ---
│       └── style                    --- yapf python formatter global configuration file
├── dump                             --- Exported configuration settings
│   ├── dconf                        ---
│   │   ├── arch.dconf               --- Selected entries from 'dconf dump /' in Arch
│   │   └── manjaro.dconf            --- Result of 'dconf dump /' in Manjaro (deprecated)
│   ├── google-chrome                ---
│   │   └── vimium.conf              --- Configuration for chrome vimium extension
│   ├── insync                       ---
│   │   └── ignorerules              ---
│   └── okular                       ---
│       └── default.shortcuts        ---
├── .gitconfig                       --- global git configuration file
├── .gitignore                       ---
├── install.sh                       --- dotfiles install script
├── .local                           ---
│   ├── bin                          ---
│   │   └── squidpdf                 --- pdf splitter for Squid notes
│   └── share                        ---
│       ├── applications             ---
│       │   └── Alacritty.desktop    --- custom launch settings for Wayland
│       └── backgrounds              ---
│           └── GH2.jpg              --- placeholder background
├── .p10k.zsh                        --- powerlevel theme settings
├── .profile                         --- sh-compatible login startup file
├── .pylintrc                        --- pylint global configuration file
├── README.md                        --- dotfiles overview
├── root                             ---
│   ├── etc                          ---
│   │   ├── logid.cfg                --- logid configuration file for Logitech peripherals
│   │   ├── modprobe.d               ---
│   │   │   └── hid_apple.conf       --- NuPhy Air75 fix for function keys
│   │   └── vconsole.conf            --- Linux virtual console configuration file
│   └── usr                          ---
│       ├── local                    ---
│       │   └── bin                  ---
│       │       ├── colortest        --- prints 256 terminal colors
│       │       └── vis              --- execute "vi -S" in closest parent directory
│       └── share                    ---
│           └── kbd                  ---
│               └── keymaps          ---
│                   └── us-caps.map  --- Keymap for linux console remapping caps to escape
├── Sessionx.vim                     --- Useful vim options for maintaining dotfiles
├── .tmux                            ---
│   └── resurrect                    ---
│       └── saferestore.sh           --- safe restore script for tmux resurrect
├── .tmux.conf                       --- tmux configuration file
├── .vimrc                           --- Vim main configuration file (deprecated)
├── .zprofile                        --- zshell login startup file
└── .zshrc                           --- zshell interactive startup file
                                     ---
30 directories, 44 files             ---
```

## Installation
These dotfiles are designed to work for Arch Linux (or other Arch-based distributions). Essential packages and applications can be installed using the `install.sh` script as a user. This script attempts to setup the following:
 - yay
 - zshell (theme, completions, font)
 - tmux
 - Lunarvim
 - LaTeX
 - Gnome (desktop environment, display manager, theme)
 - dconf configuration
 - Audiovisual media viewers and basic editors
 - Insync
 - Logiops

A basic Arch installation along with `install.sh` requires ~15gb of drive space.

#### Arch Linux Installation
To setup a new computer, install Arch Linux using the [installation guide](https://wiki.archlinux.org/title/installation_guide), or use the `archinstall` utility available in live ISO's. Useful packages to install while chroot'ed using the live ISO include:
 - sudo
 - networkmanager
 - neovim
 - git
 - tmux
 - zsh
 - os-prober (for autodetecting other boot partitions with grub)
 - vi

You can install these with the command `pacman -S sudo networkmanager neovim git tmux zsh os-prober vi`. Remember to `systemctl enable NetworkManager.service` to enable NetworkManager. To enable os-prober, uncomment the following line in `/etc/default/grub`.
```
GRUB_DISABLE_OS_PROBER=false
```
Then mount the boot partitions which should be detected to `/mnt` and remake the grub configuration file with the command `grub-mkconfig -o /boot/grub/grub.cfg`. After rebooting, make a new user with the following command.
```bash
useradd -m -G wheel -s /bin/zsh *username*
```
To enable `sudo`, use the command `visudo` and uncomment `%wheel AL=(ALL:ALL) NOPASSWD: ALL`. You can login as a user with `su *username*` and set a password with `passwd`, or just with the command `login`. Then, clone dotfiles in the user home directory and run `install.sh` to setup a standard configuration. To enable the Gnome display manager, `systemctl enable gdm.service` and reboot. To disable system sounds in Gnome, go to "Settings > Sound" and zero the "System Sounds" option (if it is already zero, try increasing it and decreasing it).

#### Printer Installation
Included in the `install.sh` script are packages for HP printers--in particular, the `hplip` package is used to install drivers for specific HP printers, whereas `cups` and `system-config-printer` are more general. To install the drivers for a physically connected printer, execute `hp-setup -i` in the terminal (`-i` for CLI interactive mode) and follow the prompts. See this [Stack Exchange post](https://unix.stackexchange.com/questions/359531/installing-hp-printer-driver-for-arch-linux) for more information.

## Manual Fixes
I try to avoid modifying plugin files directly, but the following have been changed to suit my needs. These changes are done automatically with the `install.sh` script.

 - **~/.tmux/plugins/tmux-resurrect/strategies/nvim_session.sh**: `nvim -S` changed to `vis`
   - `vis` attempts to execute `vi -S` in the closest parent directory that contains a `Session.vim` file. When tmux is resurrected, the cwd of the pane may not be the same as the Session.vim file, so `nvim -S` may not work.
 - **~/.local/share/lunarvim/site/pack/packer/opt/vimtex/autoload/vimtex/syntax/core.vim**: `48-57` removed from `set iskeyword`, so `nvim -S` may not work.
   - Prevents numbers from being recognized as keywords in LaTeX macros when determining syntax highlighting.
 - **/etc/bluetooth/main.conf**: `#Autoenable=false` changed to `Autoenable=true`
   - Allows bluetooth to start automatically on boot and after suspend. `main.conf` must be a normal file, rather than a symlink.

## Shell Startup Files
The key things to know regarding shell startup files are the following. By default,

 - .bash_profile is used for **login** bash shells
 - .bashrc is used for **non-login** interactive bash shells

for bash, and

 - .zprofile is used for **login** zsh shells
 - .zshrc is used for **interactive** zsh shells

for zsh. Additionally, if .bash_profile exists, then .profile will not be executed; a similar behavior occurs for zsh. Environment variables shared across different shells should be in the global .profile file (e.g. $PATH). Shell-specific settings should be left in the respective .zshrc and .bashrc files. In general, it is nice to source both the profile and rc files for bash and zsh whenever running an interactive shell. To do so, we have the following dependency structure. For zsh:

 - .zshrc &rarr; .zprofile (if not login).

And for bash:

 - .bashrc &rarr; .bash_profile (if not login)
 - .bash_profile &rarr; .bashrc (if login and interactive).

And finally, in general, shell-specific profile files source the global .profile file:

 - .{shell-profile} &rarr; .profile

## Notes
#### Using NTFS Partitions with Gnome
See [here](https://wiki.archlinux.org/title/NTFS) for more information. Linux kernels &ge; 5.15 support NTFS partitions automatically, but to allow Gnome to handle mounting NTFS partitions manually, install the `ntfs-3g` package. With this package, ntfs partitions can be automatically mounted by using Gnome Disks to select the partition, "Edit mount options", and enable "Mount at System Startup".

#### Enabling Trash on Data Partitions
To enable the use of "move to trash" on secondary partitions, the user must have the proper permissions to the partition. To enable the proper permissions, add the flag `uid=XXXX` (where `XXXX` is the desired user id--usually 1000 for the first user; can be confirmed with `id` in the terminal) to the mount options of the secondary partition in the fstab file (this can also be done with Gnome Disks).

#### LaTeX
LaTeX works on Arch Linux with the `texlive-most` package group (and `biber` for biber support). Custom LaTeX `.sty` and `.cls` files can be provided by adding a `tex/latex` directory under `~/texmf` (see the [MiKTeX page](https://miktex.org/kb/tds) for more information).
