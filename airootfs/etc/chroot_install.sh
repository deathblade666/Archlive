#!/bin/bash

# Add prompts for locale 
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
#timedatectl set-timezone America/New_York
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

mkinitcpio -P
clear
echo enter new root password
passwd

# Configure Bootload
# pacman -S grub efibootmgr <<< Y
# mkdir /boot/efi
# mount /dev/nvme0n1p1 /boot/efi
# grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
# grub-mkconfig -o /boot/grub/grub.cfg

# systemd-boot
bootctl install
# get UUID
uuid=lsblk -dno UUID /dev/nvme0n1p3
#mount /dev/nvme0n1p1 /boot
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


#pacman -S --noconfirm dhcpcd ebtables fakeroot sudo dnsmasq archiso libvirt virt-manager git curl wget alsa-utils netctl dialog wpa_supplicant polkit-gnome zsh go base-devel htop nfs-utils vi vim hsetroot neofetch xorg xorg-xinit qemu ovmf nvidia chromium steam alacritty discord qtile ranger docker pipewire pipwire-pulse pipewire-jack zathura pacmanfm qview ddclient obsidian  <<< Y

# Create user
systemctl start systemd-homed
clear
echo enter user name
read User
echo "set default shell (zsh/bash)"
read Setshell
clear
echo "add $User to sudoers file? [y/n]"
read Allthethings
if [$Allthethings = "y"]
then 
  echo "$User ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi
clear
homectl create $User --storage=luks --shell=/bin/$Setshell --member-of=docker

# set services to run on boot
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-homed
systemctl enable docker

# mv /config/10-monitor.conf /etc/X11/xorg.conf.d/10-monitor.conf

#amixer sset Master unmute
#amixer sset Speaker unmute

# install portainer
#docker volume create portainer_data
#docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

# install dwm
#git clone https://github.com/deathblade666/dotfiles/.config/dwm /root/dwm
#git clone https://github.com/deathblade666/.config/scripts/dwm /home/$User/.config/scripts/dwm
#cd /root/dwm
#make clean install

rm /etc/install.sh
echo User creation and application installation is complete, you may now reboot into your new system.
