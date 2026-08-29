#!/bin/bash

rootPartition=$1
installDisk=$2
efiPartition=$3
swapPartition=$4
Hostname=$5
rootpw1=$6
timezone=$7
locale=$8
ACCOUNT_TYPE=$9
User=${10}
Setshell=${11}
sudo_access=${12}
HOME_SIZE=${13}
DE=${14}

CONFIG_FILE="/root/.net_config"

status_complete() {
    printf "%s... Done.\n" "$1"
}

configure_locale() {
    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
    hwclock --systohc
    echo "$locale UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=$locale" > /etc/locale.conf
    export LANG=$locale
}

configure_hostname() {
    echo "$Hostname" > /etc/hostname
    cat > /etc/hosts << EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 $Hostname
EOF
}

set_root_password() {
    echo -e "$rootpw1\n$rootpw1" | passwd
    clear
}

check_ethernet() {
    eth_device=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^e(n|th|np)')
    if [ -n "$eth_device" ]; then
        echo "Found '$eth_device'." >&2
        cat > /etc/systemd/network/20-wired.network << EOF
[Match]
Name=$eth_device

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes

[DHCP]
UseDNS=true
EOF
    else
        echo "No Ethernet interface detected. Skipping Ethernet setup." >&2
    fi
}

check_wifi() {
    wifi_device=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)

    if [ -n "$wifi_device" ]; then
        echo "================================================="
        echo "           Wi-Fi Configuration"
        echo "================================================="
        echo "Found Wi-Fi interface: $wifi_device"

        if [ -f "$CONFIG_FILE" ]; then
            echo "Found saved network configuration. Automating setup..."
            source "$CONFIG_FILE"
            SSID="$WIFI_SSID"
            WIFIPASS="$WIFI_PASS"
            AUTO_CONF=true
        fi

        if [ "$AUTO_CONF" = true ]; then
            mkdir -p /etc/NetworkManager/system-connections
            cat > "/etc/NetworkManager/system-connections/$SSID.nmconnection" << EOF
[connection]
id=$SSID
uuid=$(cat /proc/sys/kernel/random/uuid)
type=wifi
match-device=type:wifi

[wifi]
mode=infrastructure
ssid=$SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$WIFIPASS

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto
EOF
            chmod 600 "/etc/NetworkManager/system-connections/$SSID.nmconnection"
        fi
    else
        echo "[INFO] No Wi-Fi interface detected. Skipping Wi-Fi setup."
    fi
}

install_bootloader() {
    bootctl install
}

configure_boot_entries() {
    uuid=$(lsblk -no UUID "$rootPartition")
    cat > /boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF
    cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$uuid rw
EOF
    bootctl update
}

enable_multilib() {
    sed -i -e '/#\[multilib\]/,+1s/^#//' /etc/pacman.conf
}

setup_user_account() {
    if [ "$ACCOUNT_TYPE" = "traditional" ]; then
        echo "Creating traditional UNIX user: $User..."
        useradd -m -g users -G wheel -s "$Setshell" "$User"
        
        echo "Set password for $User:"
        passwd "$User"
        
        if [ "$sudo_access" = "true" ]; then
            echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
            chmod 440 /etc/sudoers.d/10-wheel
        fi

    elif [ "$ACCOUNT_TYPE" = "homed" ]; then
        echo "systemd-homed selected. Deferring account creation to first boot..."
        
        # Enable systemd-homed daemon
        systemctl enable systemd-homed 2>&1 | grep -vE 'Created symlink|is not a native service'

        # Generate config for user.sh on first boot
        cat > /root/user.conf << EOF
USERNAME="$User"
HOME_SIZE="$HOME_SIZE"
SHELL="$Setshell"
SUDO_ACCESS="$sudo_access"
EOF

        # Dynamically build and enable first-boot.service ONLY for homed
        cat > /etc/systemd/system/first-boot.service << EOF
[Unit]
Description=First Boot systemd-homed User Setup
After=multi-user.target
ConditionPathExists=/root/user.conf

[Service]
Type=simple
ExecStart=/root/user.sh
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
KillMode=process
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable first-boot.service 2>&1 | grep -vE 'Created symlink|is not a native service'
        systemctl mask getty@tty1.service 
    fi
}

enable_system_services() {
    system_type=$(hostnamectl | grep "Chassis")
    if [[ "$DE" == "KDE" || "$DE" == "Sway" || "$DE" == "Hyprland" ]]; then
      mkdir -p /etc/sddm.conf.d
  cat > /etc/sddm.conf.d/wayland.conf << 'EOF'
[General]
DisplayServer=wayland
EOF
      systemctl enable sddm 2>&1 | grep -vE 'Created symlink|is not a native service'
    elif [[ "$DE" == "GNOME" ]]; then
      systemctl enable gdm 2>&1 | grep -vE 'Created symlink|is not a native service'
    fi

    systemctl enable bluetooth 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl enable NetworkManager 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl enable systemd-resolved 2>&1 | grep -vE 'Created symlink|is not a native service'
    
    # Enable systemd-timesyncd for default Arch NTP time synchronization
    systemctl enable systemd-timesyncd 2>&1 | grep -vE 'Created symlink|is not a native service'
    
    systemctl enable docker 2>&1 | grep -vE 'Created symlink|is not a native service'
    
    # Enable optional services if installed
    systemctl enable cups 2>/dev/null || true

    if [[ $system_type == *"laptop"* ]]; then
        if [[ -f /etc/tlp.conf ]]; then
            cp /etc/tlp.conf /etc/tlp.conf.bak
        fi

        tee /etc/tlp.conf > /dev/null <<EOF
# TLP Configuration

CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance

START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=80

USB_AUTOSUSPEND=1
WIFI_PWR_ON_BAT=1

DISK_APM_LEVEL_ON_BAT="128 128"
DISK_APM_LEVEL_ON_AC="254 254"
EOF
        systemctl enable tlp.service 2>/dev/null || true
    fi
}

check_ethernet
check_wifi
configure_locale
configure_hostname
set_root_password
install_bootloader
configure_boot_entries
enable_multilib
setup_user_account
enable_system_services
exit