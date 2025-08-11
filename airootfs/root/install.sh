#!/bin/bash

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

echo "[$(date)] Starting Arch Linux installation..."

# Sync time
timedatectl

while true; do
    clear
    echo "================================================="
    echo "           Arch Linux Installation"
    echo "================================================="
    echo
    
    mapfile -t drives < <(lsblk -d -n -o NAME,SIZE,TYPE | awk '$3 == "disk" && $1 !~ /^(loop|zram|ram)/ {print $1, $2}')
    if [ ${#drives[@]} -eq 0 ]; then
        echo "[ERROR] No physical drives found."
        echo "Please ensure your storage device is properly connected."
        exit 1
    fi

    echo "Available storage devices:"
    echo "================================================="
    for i in "${!drives[@]}"; do
        name=$(echo "${drives[$i]}" | awk '{print $1}')
        size=$(echo "${drives[$i]}" | awk '{print $2}')
        raw_model=$(udevadm info --query=property --name="/dev/$name" | grep "ID_MODEL=" | cut -d= -f2)
        model=$(echo "${raw_model:-Unknown}" | sed 's/_/ /g')
        
        # Add some visual formatting
        printf "  %d) %-12s │ %-8s │ %s\n" "$((i+1))" "/dev/$name" "$size" "$model"
    done
    echo "================================================="
    echo

    read -p "Select a drive by number (1-${#drives[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#drives[@]}" ]; then
        echo
        echo "[ERROR] Invalid selection. Please choose a number between 1 and ${#drives[@]}."
        echo
        read -p "Press Enter to continue..."
        continue
    fi

    selected_name=$(echo "${drives[$((choice-1))]}" | awk '{print $1}')
    selected_drive="/dev/$selected_name"
    clear
    echo
    echo "================================================="
    echo "WARNING: DESTRUCTIVE OPERATION AHEAD!"
    echo "================================================="
    echo "Selected drive: $selected_drive"
    echo
    echo "*** ALL DATA on this drive will be PERMANENTLY ERASED! ***"
    echo "*** This action CANNOT be undone! ***"
    echo "*** Make sure you have backups of important data! ***"
    echo
    echo "The following partitions will be created:"
    echo "  • 1GB EFI System Partition"
    echo "  • 4GB Swap Partition" 
    echo "  • Remaining space for Btrfs root filesystem"
    echo
    echo "================================================="
    
    read -p "Type 'YES' (all caps) to confirm, or anything else to cancel: " confirm
    if [ "$confirm" = "YES" ]; then
        echo
        echo "[SUCCESS] Confirmed! Proceeding with installation on $selected_drive"
        break
    else
        echo
        echo "[CANCELLED] Operation cancelled. Let's choose a different drive..."
        echo
        read -p "Press Enter to continue..."
    fi
done

# User Account Creation Prompts
clear
echo "================================================="
echo "           User Account Setup"
echo "================================================="
echo

# Get username
while true; do
    read -p "Enter username: " User
    User=$(echo "$User" | xargs)  # Trim whitespace
    
    if [ -z "$User" ]; then
        echo "[ERROR] Username cannot be empty. Please try again."
        echo
        continue
    fi
    
    # Basic username validation
    if ! [[ "$User" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "[ERROR] Username must start with lowercase letter or underscore,"
        echo "        and contain only lowercase letters, numbers, underscores, and hyphens."
        echo
        continue
    fi
    
    break
done

# Get home directory size
while true; do
    read -p "Enter home directory size (e.g., 5G, 500M, 10G): " home_size
    home_size=$(echo "$home_size" | xargs)  # Trim whitespace
    
    if [ -z "$home_size" ]; then
        echo "[ERROR] Home size cannot be empty. Please try again."
        echo
        continue
    fi
    
    # Validate format (number followed by K, M, G, or T)
    if ! [[ "$home_size" =~ ^[0-9]+[KMGT]?$ ]]; then
        echo "[ERROR] Invalid format. Please use format like: 5G, 500M, 1T, etc."
        echo
        continue
    fi
    
    break
done

# Get list of valid shells
echo
echo "Available shells:"
mapfile -t shells < <(grep '^/bin/' /etc/shells)
for i in "${!shells[@]}"; do
    shell_name=$(basename "${shells[$i]}")
    echo "$((i+1)). $shell_name (${shells[$i]})"
done

# Get shell selection
while true; do
    read -p "Select shell (1-${#shells[@]}): " shell_choice
    
    if ! [[ "$shell_choice" =~ ^[0-9]+$ ]] || [ "$shell_choice" -lt 1 ] || [ "$shell_choice" -gt "${#shells[@]}" ]; then
        echo "[ERROR] Invalid selection. Please choose 1-${#shells[@]}."
        echo
        continue
    fi
    
    Setshell="${shells[$((shell_choice-1))]}"
    break
done

# Ask about sudo access
echo
if ask_yes_no "Add $User to sudoers file?"; then
    sudo_access="true"
else
    sudo_access="false"
fi

# Desktop Environment Selection
clear
echo "================================================="
echo "           Desktop Environment (Wayland)"
echo "================================================="
echo

desktop_packages=""
selected_de=""
display_manager=""

echo "Available Wayland Desktop Environments:"
echo "1. GNOME (Full-featured desktop with native Wayland support)"
echo "2. KDE Plasma (Feature-rich desktop with excellent Wayland support)"
echo "3. Sway (Wayland-based tiling window manager)"
echo "4. Hyprland (Modern tiling compositor with animations)"
echo "5. None (Command line only)"
echo
echo "--------------------------------------------------------------------"
echo
echo "Note: Hyprland and Sway do not come with a display manager as such"
echo "if one is desired it must be installed an configured after first boot"
echo

while true; do
    read -p "Select desktop environment (1-5): " de_choice
    
    case "$de_choice" in
        1)
            selected_de="GNOME"
            desktop_packages="gnome gnome-extra"
            display_manager="gdm"
            break
            ;;
        2)
            selected_de="KDE Plasma"
            desktop_packages="plasma-meta kde-applications"
            display_manager="sddm"
            break
            ;;
        3)
            selected_de="Sway"
            desktop_packages="sway swayidle swaylock waybar foot grim slurp wl-clipboard"
            display_manager=""
            break
            ;;
        4)
            selected_de="Hyprland"
            desktop_packages="hyprland waybar foot grim slurp wl-clipboard hyprpaper hypridle hyprlock"
            display_manager=""
            break
            ;;
        5)
            selected_de="None"
            desktop_packages=""
            display_manager=""
            break
            ;;
        *)
            echo "[ERROR] Invalid selection. Please choose 1-5."
            continue
            ;;
    esac
done

# Append desktop packages to pkglist.txt if selected
if [ -n "$desktop_packages" ]; then
    echo
    echo "Adding $selected_de packages to installation list..."
    echo "# Desktop Environment: $selected_de" >> pkglist.txt
    for package in $desktop_packages; do
        echo "$package" >> pkglist.txt
    done
    echo >> pkglist.txt
fi

# Append polkit agent to pkglist.txt if not already added
if [[ "$selected_de" == "Sway" || "$selected_de" == "Hyprland" || "$selected_de" == "None" ]]; then
    grep -qxF "polkit-gnome" pkglist.txt || echo "polkit-gnome" >> pkglist.txt
fi

# Create user configuration file
cat > /root/user.conf << EOF
USERNAME="$User"
HOME_SIZE="$home_size"
SHELL="$Setshell"
SUDO_ACCESS="$sudo_access"
DESKTOP_ENVIRONMENT="$selected_de"
DISPLAY_MANAGER="$display_manager"
EOF

clear
echo "================================================="
echo "           Beginning Installation"
echo "================================================="
echo "Target Drive: $selected_drive"
if [ "$selected_de" != "None" ]; then
    echo "Desktop Environment: $selected_de"
fi
echo "================================================="
echo

partitions=$(lsblk -ln -o NAME | grep "^$(basename "$selected_drive")" | grep -o '[0-9]*$')
fdisk_cmd=""
for p in $partitions; do
    fdisk_cmd+="d\n$p\n"
done
fdisk_cmd+="w\n"

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

run_multiphase() {
    format_disk() {
        echo -e "$fdisk_cmd" | fdisk "$selected_drive"
    }

    create_partitions() {
        echo -e "o\nn\np\n1\n\n+1G\nn\np\n2\n\n+4G\nn\np\n3\n\n\nw" | fdisk "$selected_drive"
    }

    configure_partitions() {
        drive_base=$(basename "$selected_drive")
        if [[ "$drive_base" =~ ^(nvme|mmcblk) ]]; then
            suffix="p"
        else
            suffix=""
        fi
        selected_drive1="${selected_drive}${suffix}1"
        selected_drive2="${selected_drive}${suffix}2"
        selected_drive3="${selected_drive}${suffix}3"
    }

    validate_partitions() {
        for part in "$selected_drive1" "$selected_drive2" "$selected_drive3"; do
            if [ ! -b "$part" ]; then
                echo "Error: Partition $part not found." >&2
                exit 1
            fi
        done
    }

    format_efi() { mkfs.fat -F32 "$selected_drive1"; }
    format_root() { mkfs.btrfs -f "$selected_drive3"; }
    setup_swap() { mkswap "$selected_drive2"; }
    mount_root() { mount "$selected_drive3" /mnt; }
    mount_efi() { mount --mkdir "$selected_drive1" /mnt/boot; }
    activate_swap() { swapon "$selected_drive2"; }

    phase_spinner "Deleting existing partitions" format_disk
    phase_spinner "Re-Partitioning disk" create_partitions

    configure_partitions
    validate_partitions

    phase_spinner "Formatting EFI partition" format_efi
    phase_spinner "Formatting Btrfs root partition" format_root
    phase_spinner "Setting up swap partition" setup_swap
    phase_spinner "Mounting root partition" mount_root
    phase_spinner "Mounting EFI partition" mount_efi
    phase_spinner "Activating swap" activate_swap
}
run_multiphase

sed -i -e '/#\[multilib\]/,+1s/^#//' /etc/pacman.conf

detect_gpu_and_append_pkg() {
    gpu_info=$(lspci | grep -i 'vga\|3d\|2d')
    pkglist_file="pkglist.txt"

    if echo "$gpu_info" | grep -qi nvidia; then
        echo "NVIDIA GPU detected."
        {
            echo "# GPU Drivers: NVIDIA"
            echo "nvidia-dkms"
            echo "nvidia-utils"
            echo "lib32-nvidia-utils"
            echo "nvidia-settings"
            echo
        } >> "$pkglist_file"

    elif echo "$gpu_info" | grep -qi amd; then
        echo "AMD GPU detected."
        {
            echo "# GPU Drivers: AMD"
            echo "xf86-video-amdgpu"
            echo "mesa"
            echo "lib32-mesa"
            echo
        } >> "$pkglist_file"

    elif echo "$gpu_info" | grep -qi intel; then
        echo "Intel integrated graphics detected."
        {
            echo "# GPU Drivers: Intel"
            echo "xf86-video-intel"
            echo "mesa"
            echo "lib32-mesa"
            echo "vulkan-intel"
            echo
        } >> "$pkglist_file"

    else
        echo "No recognizable GPU found. Skipping package append."
    fi
}

detect_gpu_and_append_pkg

detect_cpu_and_append_ucode() {
    cpu_vendor=$(lscpu | grep -i 'vendor' | awk '{print $NF}')
    pkglist_file="pkglist.txt"

    case "$cpu_vendor" in
        GenuineIntel)
            echo "Intel CPU detected."
            {
                echo "# CPU Microcode: Intel"
                echo "intel-ucode"
                echo
            } >> "$pkglist_file"
            ;;
        AuthenticAMD)
            echo "AMD CPU detected."
            {
                echo "# CPU Microcode: AMD"
                echo "amd-ucode"
                echo
            } >> "$pkglist_file"
            ;;
        *)
            echo "Unknown CPU vendor. Skipping microcode package."
            ;;
    esac
}

detect_cpu_and_append_ucode

phase_spinner "Optimizing Repo Mirror List" bash -c 'pacman -Sy && reflector --latest 200 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist'
phase_spinner "Installing Base System" pacstrap /mnt $(awk '!/^#/ { gsub(/#.*/, ""); print }' pkglist.txt)

genfstab -U /mnt >> /mnt/etc/fstab
cp /root/user.sh /mnt/root/user.sh
cp /root/chroot_install.sh /mnt/root/chroot_install.sh
cp /root/user.conf /mnt/root/user.conf

echo "Configuring new system root... "
arch-chroot /mnt /root/chroot_install.sh "$selected_drive3" "$selected_drive" "$selected_drive1" "$selected_drive2"

rm /mnt/root/chroot_install.sh
echo -n "Unmounting drive... "
umount /mnt/boot
umount /mnt
swapoff "$selected_drive2"
echo "Done."
echo "System configured... Done."
echo "Reboot your system to setup user accounts!"