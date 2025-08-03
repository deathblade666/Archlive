#!/bin/bash

# Sync time
timedatectl

# set up partitions: this sets a root partition, SWAP partition (4G) and a EFI partition (1G)
(echo o; echo n; echo p; echo 1; echo""; echo +1G; echo t; echo ef; echo n; echo p; echo 2; echo ""; echo 4G; echo n; echo p; echo 3; echo ""; echo ""; echo w) | fdisk /dev/nvme0n1

#format Partitions
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs /dev/nvme0n1p3 <<< Y
mkswap /dev/nvme0n1p2

#mount Partitions
mount /dev/nvme0n1p3 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2

# update repos
pacman -Syy

# install reflector is not already and sort mirrors
pacman -S reflector --noconfirm
reflector --latest 200 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist

# install base system
pacstrap /mnt base-devel linux linux-firmware vim docker pipewire alacritty pipwire-pulse steam htop git curl wget zsh vi nvidia qview fakeroot pcmanfm wayland xorg-xwayland

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab
# cp /root/config_setup.sh /mnt/etc/skel/config_setup.sh
# cp /root/.xinitrc /mnt/etc/skel/.xinitrc
cp /etc/chroot_install.sh /mnt/root/chroot_install.sh
# cp /etc/post_install.sh /mnt/config/post_install.sh
#mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
#cp /etc/pacman.conf /mnt/etc/pacman.conf
# cp /root/10-monitor.conf /mnt/config/10-monitor.conf
# cp /root/arch-wallpaper.png /mnt/config/arch-wallpaper.png
arch-chroot /mnt ./root/chroot_install.sh
