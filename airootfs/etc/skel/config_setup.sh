#!/bin/bash

sudo rm /etc/chroot_install.sh

# cloning and installing oh-my-zsh and powerline fonts
git clone https://github.com/deathblade666/dot_files.git ~/.config/dot_files
cd ~/.config/dot_files/zsh/script
chmod +x install_zsh.sh
./install_zsh.sh
mv ~/.oh-my-zsh/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh.bak
cp ~/.config/dot_files/zsh/oh-my-zsh/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh
mv ~/.zshrc ~/zshrc.bak
cp ~/.config/dot_files/zsh/.zshrc ~/.zshrc

# clone i3 config
mv -r ~/.config/dot_files/i3 ~/.config/i3
mv -r ~/.config/dot_files/rofi ~/.config/rofi
mv -r ~/.config/dot_files/i3blocks ~/.config/i3blocks

# copy config files and remove old directories
cp -r ~/.config/i3config/i3 ~/.config/i3
cp -r ~/.config/kde-i3/nitrogen ~/.config/nitrogen
cp -r ~/.config/kde-i3/rofi ~/.config/rofi
rm -r ~/.config/i3config/ <<< yes <<< yes
rm -r ~/.config/kde-i3/ <<< yes <<< yes

# install yay and st terminal
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si
yay -S st <<< N
clear
echo Setup complete you may now start using this system as normal, to get a UI type "startx"
