# WSL setup notes
* Install wsl
    * wsl --install
    * wsl --install archlinux
    * Restart
    * wsl --install archlinux
    * wsl -d archlinux (to launch)
* Set up pacman:
    * pacman -Syyu
    * pacman -S git sudo vi man nvim
* Set up new user:
    * visudo -> uncomment `%wheel ALL=(ALL:ALL) ALL`
    * useradd -m -G root,wheel linstar (root group gives permission to mounted filesystems)
    * su linstar
    * Set up dotfiles:
        * cd && git clone https://github.com/ProfessorLinstar/dotfiles
        * cd dotfiles
        * ./install.sh -evlt
    * Set up github (optional):
        * git config --global credential.helper store
        * git config --global user.email \<email\>
        * git config --global user.name \<name\>
        * Make new developer token and paste on next git password prompt
    * chsh -> /usr/bin/zsh
