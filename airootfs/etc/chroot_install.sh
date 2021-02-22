#!/bin/bash
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
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
pacman -S --noconfirm dhcpcd ebtables fakeroot sudo dnsmasq archiso libvirt virt-manager git curl wget alsa-utils netctl dialog wpa_supplicant polkit-gnome zsh go base-devel htop nfs-utils vi vim hsetroot neofetch rofi i3-gaps xorg xorg-xinit qemu ovmf nvidia chromium qutebrowser steam ranger pcmanfm mpv <<< Y
useradd -m -s /bin/zsh deathmasia
clear
echo enter user password
passwd deathmasia
systemctl enable libvirtd
systemctl enable dhcpcd
mv /config/10-monitor.conf /etc/X11/xorg.conf.d/10-monitor.conf
echo 'deathmasia ALL=(ALL:ALL) ALL' >> /etc/sudoers
amixer sset Master unmute
amixer sset Speaker unmute
rm /etc/install.sh
echo User creation and application installation is complete, you may now reboot into your new system.

