#!/bin/bash

sudo rm /etc/chroot_install.sh

# cloning and installing oh-my-zsh and powerline fonts
git clone https://github.com/deathblade666/dotfiles.git ~/
cd ~/.config/dot_files/zsh/script
chmod +x install_zsh.sh
./install_zsh.sh
mv ~/.oh-my-zsh/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh.bak
cp ~/.config/zsh/oh-my-zsh/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh
mv ~/.zshrc ~/.zshrc.bak
cp ~/.config/dot_files/zsh/.zshrc ~/.zshrc

# install yay and st terminal
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si
yay -S st <<< N
clear
echo Setup complete you may now start using this system as normal, to get a UI type "startx"
