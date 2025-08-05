#!/bin/bash

# Sync time
timedatectl

while true; do
    clear
    mapfile -t drives < <(lsblk -d -n -o NAME,SIZE,TYPE | awk '$3 == "disk" && $1 !~ /^(loop|zram|ram)/ {print $1, $2}')
    if [ ${#drives[@]} -eq 0 ]; then
        echo "No physical drives found."
        exit 1
    fi

    echo "Available physical drives:"
    for i in "${!drives[@]}"; do
        name=$(echo "${drives[$i]}" | awk '{print $1}')
        size=$(echo "${drives[$i]}" | awk '{print $2}')
        raw_model=$(udevadm info --query=property --name="/dev/$name" | grep "ID_MODEL=" | cut -d= -f2)
        model=$(echo "${raw_model:-Unknown}" | sed 's/_/ /g')
        echo "$((i+1)). /dev/$name - $model $size"
    done

    read -p "Select a drive by number: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#drives[@]}" ]; then
        echo "Invalid selection."
        continue
    fi

    selected_name=$(echo "${drives[$((choice-1))]}" | awk '{print $1}')
    selected_drive="/dev/$selected_name"

    echo -e "\e[31mWARNING:\e[0m All data on $selected_drive will be erased!"
    read -p "Is this correct? (Y/n): " confirm
    confirm=${confirm:-y} 
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        break
    else
        echo "Let's try again..."
    fi
done
clear
echo "Performing the following actions on $selected_drive"

partitions=$(lsblk -ln -o NAME | grep "^$(basename "$selected_drive")" | grep -o '[0-9]*$')
fdisk_cmd=""
for p in $partitions; do
    fdisk_cmd+="d\n$p\n"
done
fdisk_cmd+="w\n"

# Spinner phase function
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

# Sort mirrors
phase_spinner "Optimizing Repo Mirror List" bash -c 'pacman -Sy && reflector --latest 200 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist'

# Install base system
phase_spinner "Installing Base System" pacstrap /mnt base steam linux linux-firmware vim sudo docker pipewire alacritty htop git curl wget zsh vi nvidia fakeroot pcmanfm wayland xorg-xwayland

# Remaining steps (no spinner)
genfstab -U /mnt >> /mnt/etc/fstab
cp /root/user.sh /mnt/root/user.sh
cp /root/chroot_install.sh /mnt/root/chroot_install.sh
arch-chroot /mnt ./root/chroot_install.sh
rm /mnt/root/chroot_install.sh
echo unmounting drive
umount /mnt/boot
umount /mnt
swapoff "$selected_drive2"
echo Setup complete, reboot your system to setup user accounts!
shutdown -h now
