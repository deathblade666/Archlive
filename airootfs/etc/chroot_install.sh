#!/bin/bash
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
timedatectl set-timezone America/New_York
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG=en_US.UTF-8
echo Arch-Linux > /etc/hostname
echo 127.0.0.1 localhost > /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.1.1 Arch-Linux >> /etc/hosts
clear
echo enter new root password
passwd
pacman -S grub efibootmgr <<< Y
mkdir /boot/efi
mount /dev/sda1 /boot/efi
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
pacman -S --noconfirm dhcpcd ebtables fakeroot sudo libvirt virt-manager git curl wget zsh go base-devel htop nfs-utils vi vim nitrogen neofetch rofi i3 xorg xorg-xinit qemu ovmf nvidia chromium steam <<< Y
useradd -m -s /bin/zsh deathmasia
clear
echo enter user password
passwd deathmasia
systemctl enable libvirtd
systemctl enable dhcpcd
mv /config/arch-wallpaper.png /home/deathmasia/wallpaper/arch-wallpaper.png
mv /config/10-monitor.conf /etc/X11/xorg.conf.d/10-monitor.conf
mv /config/bg-save.cfg /home/deathmasia/.config/nitrogen/bg-save.cfg
echo 'deathmasia ALL=(ALL:ALL) ALL' >> /etc/sudoers

