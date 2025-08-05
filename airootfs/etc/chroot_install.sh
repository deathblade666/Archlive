#!/bin/bash

ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG=en_US.UTF-8

# Hostname
clear
echo enter desired hostname
read Hostname
echo $Hostname > /etc/hostname
echo 127.0.0.1 localhost > /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.1.1 $Hostname >> /etc/hosts
clear

# Stage default network config
eth_device=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^e(n|th|np)')
#wifi_device=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^e(n|th|np)')
cat > /etc/systemd/network/20-wired.network << EOF
[Match]
Name=$eth_device

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
EOF

#cat > /etc/systemd/network/ << EOF
#[Match]
#Name=$wifi_device
#
#[Link]
#RequiredForOnline=routable
#
#[Network]
#DHCP=yes
#IgnoreCarrierLoss=3s
#EOF

clear
echo enter new root password
passwd
clear

# Configure Bootload
# pacman -S grub efibootmgr <<< Y
# mkdir /boot/efi
# mount /dev/vda1 /boot/efi
# grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
# grub-mkconfig -o /boot/grub/grub.cfg

# systemd-boot
echo setting up bootloader
bootctl install

# get UUID
uuid=$(lsblk -dno UUID /dev/vda3)
cat > /boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$uuid rw
EOF
bootctl update
clear

# set services to run on boot
systemctl enable systemd-networkd
systemctl enable systemd-homed
systemctl enable systemd-resolved
systemctl enable docker
clear

cp /etc/issue /root/issue

cat >> /etc/issue << EOF
Welcome to Arch Linux!
login with \`root\` then
Run \`user.sh\` to create your first user.

EOF
exit
