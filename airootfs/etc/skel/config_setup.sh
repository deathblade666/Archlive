#!/bin/bash

# cloning and installing oh-my-zsh and powerline fonts 
git clone https://github.com/deathblade666/zsh.git ~/.config/zsh
cd ~/.config/zsh/script
chmod +x install_zsh.sh
./install_zsh.sh
mv ~/.oh-my-zsh/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh.bak
cp ~/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh
mv ~/.zshrc ~/zshrc.bak
cp ~/.config/zsh/.zshrc ~/.zshrc

# clone i3 config
git clone https://github.com/deathblade666/i3config.git ~/.config/i3config

# clone config files
git clone https://github.com/deathblade666/kde-i3-setup.git ~/.config/kde-i3

# copy config files and remove old directories
cp -r ~/.config/i3config/i3 ~/.config/i3
cp -r ~/.config/kde-i3/rofi ~/.config/rofi
rm -r ~/.config/i3conifg/ <<< yes <<< yes
rm -r ~/.config/kde-i3/ <<< yes <<< yes

# Set wallpaper
mkdir ~/wallpaper
cp /config/arch-wallpaper.png ~/wallpaper/arch-wallpaper.png
mkdir ~/.config
cd .config
mkdir nitrogen
cp /config/bg-save.cfg /home/deathmasia/.config/nitrogen/bg-save.cfg

# install yay and st terminal
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si
yay -S st <<< N
