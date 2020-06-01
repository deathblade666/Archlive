
#!/bin/bash
(echo o; echo n; echo p; echo 1; echo""; echo +512M; echo t; echo ef; echo n; echo p; echo 2; echo ""; echo ""; echo w) | fdisk /dev/sda
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2 <<< Y
mount /dev/sda2 /mnt
pacman -Syy
pacstrap /mnt base linux linux-firmware vim nano
genfstab -U /mnt >> /mnt/etc/fstab
mkdir /mnt/config
cp /root/oh-my-zsh.sh /mnt/etc/skel/oh-my-zsh.sh
cp -r /root/config_setup.sh /mnt/etc/skel/config_setup.sh
cp /root/.xinitrc /mnt/etc/skel/.xinitrc
cp /etc/chroot_install.sh /mnt/chroot_install.sh
cp /etc/post_install.sh /mnt/config/post_install.sh
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
cp /etc/pacman.conf /mnt/etc/pacman.conf
cp /root/10-monitor.conf /mnt/config/10-monitor.conf
cp /root/arch-wallpaper.png /mnt/config/arch-wallpaper.png
arch-chroot /mnt ./chroot_install.sh

