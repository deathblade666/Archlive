#!/bin/bash

# set up partitions: this sets a root partition and a EFI partition
# EFI parition is set to 512MB
(echo o; echo n; echo p; echo 1; echo""; echo +512M; echo t; echo ef; echo n; echo p; echo 2; echo ""; echo ""; echo w) | fdisk /dev/nvme0n1
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2 <<< Y
mount /dev/nvme0n1p2 /mnt
mkdir /mnt/boot

# update repos
pacman -Syy

# install base system
pacstrap /mnt base linux linux-firmware vim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab
mkdir /mnt/config
# cp /root/config_setup.sh /mnt/etc/skel/config_setup.sh
# cp /root/.xinitrc /mnt/etc/skel/.xinitrc
cp /etc/chroot_install.sh /mnt/config/chroot_install.sh
# cp /etc/post_install.sh /mnt/config/post_install.sh
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
cp /etc/pacman.conf /mnt/etc/pacman.conf
# cp /root/10-monitor.conf /mnt/config/10-monitor.conf
# cp /root/arch-wallpaper.png /mnt/config/arch-wallpaper.png
arch-chroot /mnt ./config/chroot_install.sh
