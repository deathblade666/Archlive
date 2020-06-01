#!/bin/bash

## cloning zsh config
git clone https://github.com/deathblade666/zsh.git ~/.config/zsh
cd ~/.config/zsh/script
chmod +x install_zsh.sh
./install_zsh.sh
mv ~/.oh-my-zsh/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh.bak
cp ~/oh-my-zsh.sh ~/.oh-my-zsh/oh-my-zsh.sh
mv ~/.zshrc ~/zshrc.bak
cp ~/.config/zsh/.zshrc ~/.zshrc

## If running i3 Window Manager uncomment the following line
git clone https://github.com/deathblade666/i3config.git ~/.config/i3config

## if running KDE and want i3 to be your window manager ucomment the following line
git clone https://github.com/deathblade666/kde-i3-setup.git ~/.config/kde-i3

# uncomment the following lines for individual application configs
cp -r ~/.config/i3config/i3 ~/.config/i3
cp -r ~/.config/kde-i3/rofi ~/.config/rofi
rm -r ~/.config/i3/i3conifg/ <<< yes <<< yes
rm -r ~/.config/kde-i3/ <<< yes <<< yes

git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si
yay -S st <<< N
