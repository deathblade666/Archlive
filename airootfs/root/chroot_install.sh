#!/bin/bash

rootPartition=$1
installDisk=$2
efiPartition=$3
swapPartition=$4

# Helper functions for clean spinner output
phase_spinner() {
    local message=$1
    shift

    echo -n "$message... "
    "$@" &> /dev/null & local pid=$!

    local spinstr='|/-\\'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        printf "\r%s... [%c]  " "$message" "${spinstr:i++%${#spinstr}:1}"
        sleep 0.1
    done

    wait $pid
    local exit_code=$?
    printf "\r%s... Done.\n" "$message"
    return $exit_code
}

# For non-spinner tasks that complete immediately
status_complete() {
    printf "%s... Done.\n" "$1"
}

# Helper function for yes/no prompts
ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt (y/n): " response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Locale setup
configure_locale() {
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
    hwclock --systohc
    echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
    locale-gen
    echo LANG=en_US.UTF-8 > /etc/locale.conf
    export LANG=en_US.UTF-8
}
phase_spinner "Configuring locale" configure_locale

# Hostname setup
clear
echo "================================================="
echo "           System Configuration"
echo "================================================="
echo

while true; do
    read -p "Enter hostname for this system: " Hostname
    Hostname=$(echo "$Hostname" | xargs)  # Trim whitespace
    
    if [ -z "$Hostname" ]; then
        echo "[ERROR] Hostname cannot be empty. Please try again."
        echo
        continue
    fi
    
    # Basic hostname validation
    if ! [[ "$Hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "[ERROR] Hostname can only contain letters, numbers, and hyphens."
        echo
        continue
    fi
    
    if [[ "$Hostname" =~ ^- ]] || [[ "$Hostname" =~ -$ ]]; then
        echo "[ERROR] Hostname cannot start or end with a hyphen."
        echo
        continue
    fi
    
    break
done

configure_hostname() {
    echo "$Hostname" > /etc/hostname
    cat > /etc/hosts << EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 $Hostname
EOF
}

configure_hostname
status_complete "Setting system hostname to '$Hostname'"

# Root password setup
clear
echo "================================================="
echo "           Root Password Setup"
echo "================================================="
echo

while true; do
    read -s -p "Enter new root password: " rootpw1
    echo
    read -s -p "Confirm root password: " rootpw2
    echo

    if [ -z "$rootpw1" ]; then
        echo "[ERROR] Password cannot be empty. Please try again."
        echo
        continue
    fi
    
    if [ "$rootpw1" != "$rootpw2" ]; then
        echo "[ERROR] Passwords do not match. Please try again."
        echo
        continue
    else
        set_root_password() {
            echo -e "$rootpw1\n$rootpw1" | passwd
        }
        set_root_password
        status_complete "Root password configured"
        break
    fi
done
clear

# Ethernet setup
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
phase_spinner "Checking for Ethernet interface" check_ethernet

# Wi-Fi setup
check_wifi() {
    wifi_device=$(iw dev | awk '$1=="Interface"{print $2}')
}
phase_spinner "Checking for Wi-Fi interface" check_wifi

if [ -n "$wifi_device" ]; then
    clear
    echo "================================================="
    echo "           Wi-Fi Configuration"
    echo "================================================="
    echo "Found Wi-Fi interface: $wifi_device"
    echo

    if ask_yes_no "Configure Wi-Fi network?"; then
        if ! command -v wpa_supplicant &> /dev/null; then
            echo "[ERROR] 'wpa_supplicant' is not installed. Skipping Wi-Fi setup."
        else
            scan_wifi() {
                available_ssids=($(iwlist "$wifi_device" scan | awk -F':' '/ESSID:/ {print $2}' | sed 's/"//g' | sort -u))
            }
            phase_spinner "Scanning for available Wi-Fi networks" scan_wifi

            echo
            if [ "${#available_ssids[@]}" -eq 0 ]; then
                echo "No networks found in scan."
                read -p "Enter SSID manually: " SSID
            else
                echo "Available networks:"
                echo "--------------------"
                for i in "${!available_ssids[@]}"; do
                    echo "$i) ${available_ssids[$i]}"
                done
                echo "--------------------"
                echo

                read -p "Select network number to connect to: " ssid_choice

                # Validate input
                if [[ "$ssid_choice" =~ ^[0-9]+$ ]] && [ "$ssid_choice" -ge 0 ] && [ "$ssid_choice" -lt "${#available_ssids[@]}" ]; then
                    SSID="${available_ssids[$ssid_choice]}"
                else
                    echo "Invalid selection. Exiting or ask for manual entry."
                    exit 1
                fi
            fi

            echo
            read -s -p "Enter Wi-Fi password for '$SSID': " WIFIPASS
            echo
            echo

            generate_wpa_config() {
                wpa_passphrase "$SSID" "$WIFIPASS" > /etc/wpa_supplicant/$wifi_device.conf
            }
            phase_spinner "Generating WPA configuration" generate_wpa_config

            enable_wpa_service() {
                systemctl enable wpa_supplicant@$wifi_device 2>&1 | grep -vE 'Created symlink|is not a native service'
            }
            phase_spinner "Enabling WPA supplicant service" enable_wpa_service

            create_wifi_network() {
                cat > /etc/systemd/network/25-wireless.network << EOF
[Match]
Name=$wifi_device

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
IgnoreCarrierLoss=3s

[DHCP]
UseDNS=true
EOF
            }
            phase_spinner "Creating systemd-networkd config for Wi-Fi" create_wifi_network
        fi
    else
        echo "[INFO] Skipping Wi-Fi configuration."
    fi
else
    echo "[INFO] No Wi-Fi interface detected. Skipping Wi-Fi setup."
fi

# Bootloader setup
install_bootloader() {
    bootctl install
}
clear
phase_spinner "Setting up bootloader" install_bootloader

# UUID setup
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
phase_spinner "Configuring boot entries" configure_boot_entries

# Enable Multilib
enable_multilib() {
    sed -i -e '/#\[multilib\]/,+1s/^#//' /etc/pacman.conf
}
phase_spinner "Enabling Multilib repository" enable_multilib

# Enable services
enable_system_services() {
    system_type=$(hostnamectl | grep "Chassis")

    cat > /etc/systemd/system/first-boot.service << EOF
[Unit]
Description=First Boot User Account Setup
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
    systemctl enable systemd-networkd 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl enable systemd-homed 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl enable systemd-resolved 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl enable docker 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl enable first-boot 2>&1 | grep -vE 'Created symlink|is not a native service'
    systemctl mask getty@tty1.service 

    if [[ $system_type == *"laptop"* ]]; then
        if [[ -f /etc/tlp.conf ]]; then
            cp /etc/tlp.conf /etc/tlp.conf.bak
        fi
    fi

        tee /etc/tlp.conf > /dev/null <<EOF
# TLP Configuration - Generated by setup-tlp.sh

# --- CPU Settings ---
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance

# --- Battery Charge Thresholds (BAT0) ---
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=80

# --- USB Autosuspend ---
USB_AUTOSUSPEND=1

# --- WiFi Power Saving ---
WIFI_PWR_ON_BAT=1

# --- Disk Power Management ---
DISK_APM_LEVEL_ON_BAT="128 128"
DISK_APM_LEVEL_ON_AC="254 254"
EOF
        systemctl enable tlp.service
}
phase_spinner "Enabling system services" enable_system_services

source /root/user.conf


clear
echo "================================================="
echo "           Installation Summary"
echo "================================================="
echo
echo "Operations performed on $installDisk:"
echo "-------------------------------------------------"
status_complete "Deleting existing partitions"
status_complete "partitioned $installDisk"  
status_complete "    EFI: 1GB | Swap: 4GB | Root: rest of disk"
status_complete "Formated $efiPartition"
status_complete "    EFI: FAT-32"
status_complete "Formated $rootPartition"
status_complete "    Root: btrfs"
status_complete "Formated $swapPartition"
status_complete "    Swap: swap"
status_complete "Mounted root partition"
status_complete "    $rootPartition mounted to /mnt"
status_complete "Mounted EFI partition"
status_complete "    $efiPartition mounted to /mnt/boot"
status_complete "Activated swap"
status_complete "    swap activated"
status_complete "Optimized Repo Mirror List"
status_complete "Installed Base System"
status_complete "    Installed Compositor: $DESKTOP_ENVIRONMENT"
status_complete "    Created User: $USERNAME"
status_complete "Configured new system root.."
status_complete "    Hostname set"
status_complete "    Root password configured"
status_complete "    User account configured"
status_complete "    WiFi Setup"
status_complete "    Bootloader setup"
status_complete "    Configured Boot Entries"
status_complete "    Enabled Mulitlib repos"
status_complete "    Enabled system services"
exit