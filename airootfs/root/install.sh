#!/bin/bash

phase_spinner() {
    local message=$1
    shift

    local tmp_log
    tmp_log=$(mktemp)

    echo -n "$message... "
    "$@" > "$tmp_log" 2>&1 &
    local pid=$!

    local spinstr='|/-\\'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        printf "\r%s... [%c]  " "$message" "${spinstr:i++%${#spinstr}:1}"
        sleep 0.1
    done

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r%s... Done.\n" "$message"
        rm -f "$tmp_log"
    else
        printf "\r%s... Failed!\n" "$message"
        echo "----------------- Output / Error Log -----------------"
        cat "$tmp_log"
        echo "------------------------------------------------------"
        rm -f "$tmp_log"
    fi

    return $exit_code
}

ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt (y/n): " response
        response=$(echo "$response" | xargs | tr '[:upper:]' '[:lower:]')
        
        case "$response" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}

print_columns() {
    local -n arr=$1
    local offset=${2:-1}
    local cols=3
    local width=25
    local count=${#arr[@]}

    for ((i=0; i<count; i+=cols)); do
        for ((j=0; j<cols; j++)); do
            local idx=$((i + j))
            if (( idx < count )); then
                printf "%-4s %-*s" "$((idx + offset))." "$width" "${arr[idx]}"
            fi
        done
        echo
    done
}

clear
rfkill unblock all

network_config() {
    CONFIG_FILE=".net_config"

    check_internet() {
        ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1
    }

    get_wifi_device() {
        iw dev | awk '$1=="Interface"{print $2}'
    }

    echo "Checking internet connection..."

    if check_internet; then
        echo "Check passed: You are online."
    else
        echo "No internet connection detected."
    
        DEVICE=$(get_wifi_device)
        if [ -z "$DEVICE" ]; then
            echo "Error: No WiFi adapter detected. Wired connection required."
            exit 1
        fi
        read -p "Connect to WiFi now? (y/n): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            echo "Process aborted."
            exit 1
        fi

        while true; do
            echo "Scanning for networks on $DEVICE..."
            iwctl station "$DEVICE" scan
            sleep 2 
            clear
            echo "--- Available Networks ---"
            mapfile -t networks < <(iwctl station "$DEVICE" get-networks | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR>4 {print substr($0, 1, 32)}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

            if [ ${#networks[@]} -eq 0 ]; then
                clear
                echo "No networks found. Retrying scan..."
                continue
            fi

            for i in "${!networks[@]}"; do
                printf "%2d) %s\n" "$((i+1))" "${networks[$i]}"
            done
            echo " q) Quit"

            read -p "Select a network (1-${#networks[@]}): " selection
            [[ "$selection" == "q" ]] && exit 1

            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#networks[@]}" ]; then
                selected_ssid="${networks[$((selection-1))]}"
                clear
                read -s -p "Enter Password for $selected_ssid: " password
                echo -e "\nAttempting to connect..."

                if iwctl station "$DEVICE" connect "$selected_ssid" --passphrase "$password"; then
                    echo "Verifying internet access..."
                
                    SUCCESS=false
                    for i in {1..5}; do
                        sleep 2
                        if check_internet; then
                            SUCCESS=true
                            break
                        fi
                    done

                    if [ "$SUCCESS" = true ]; then
                        echo "Successfully connected!"
                        echo "Saving configuration to $CONFIG_FILE..."
                        cat <<EOF > "$CONFIG_FILE"
WIFI_INTERFACE="$DEVICE"
WIFI_SSID="$selected_ssid"
WIFI_PASS="$password"
EOF
                        chmod 600 "$CONFIG_FILE"
                        break 
                    else
                        echo "!! Connected to WiFi, but no internet access detected."
                    fi
                else
                    echo "!! Connection failed. Check your password."
                fi
            else
                echo "!! Invalid selection."
            fi
        done
    fi

    clear
}

echo "[$(date)] Starting Arch Linux installation..."

timedatectl

drive_config() {
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
}

Desktop_Environment_Selection() {
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
                desktop_packages="plasma-meta kde-applications sddm-kcm"
                display_manager="sddm"
                break
                ;;
            3)
                selected_de="Sway"
                desktop_packages="sway swayidle swaylock-effects waybar foot fuzzel mako grim slurp swappy wl-clipboard cliphist pavucontrol brightnessctl gammastep wlr-randr polkit-gnome"
                display_manager="sddm"
                break
                ;;
            4)
                selected_de="Hyprland"
                desktop_packages="hyprland waybar foot fuzzel swaync hyprpaper hypridle hyprlock grim slurp swappy wl-clipboard cliphist pavucontrol brightnessctl gammastep wlr-randr polkit-gnome"
                display_manager="sddm"
                break
                ;;
            5)
                selected_de="None"
                desktop_packages="polkit-gnome"
                display_manager=""
                break
                ;;
            *)
                echo "[ERROR] Invalid selection. Please choose 1-5."
                continue
                ;;
        esac
    done

    if [ -n "$desktop_packages" ]; then
        echo
        echo "Adding $selected_de packages to installation list..."
        echo "# Desktop Environment: $selected_de" >> pkglist.txt
        
        # Combine desktop packages and optional display manager
        all_targets="$desktop_packages $display_manager"

        for package in $all_targets; do
            # Only append if the package isn't already present as an exact line in pkglist.txt
            if ! grep -qE "^[[:space:]]*${package}[[:space:]]*$" pkglist.txt; then
                echo "$package" >> pkglist.txt
                echo "  + Added $package"
            else
                echo "  ~ Skipping $package (already in pkglist.txt)"
            fi
        done
        echo >> pkglist.txt
    fi
}

User_Config() {
    clear
    echo "================================================="
    echo "              User Account Setup"
    echo "                   Basic Info"
    echo "================================================="
    echo

    # 1. Username
    while true; do
        read -p "Enter username: " User
        User=$(echo "$User" | xargs)
    
        if [ -z "$User" ]; then
            echo "[ERROR] Username cannot be empty. Please try again."
            echo
            continue
        fi
    
        if ! [[ "$User" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            echo "[ERROR] Username must start with lowercase letter or underscore,"
            echo "        and contain only lowercase letters, numbers, underscores, and hyphens."
            echo
            continue
        fi
    
        break
    done

    # 2. Account Type Selection
    echo
    echo "Select Account Strategy:"
    echo "1) Traditional UNIX user (useradd / /etc/passwd)"
    echo "2) systemd-homed (Portable / Managed user account)"
    echo
    while true; do
        read -p "Select choice (1-2): " acct_choice
        case "$acct_choice" in
            1)
                ACCOUNT_TYPE="traditional"
                HOME_SIZE=""
                break
                ;;
            2)
                ACCOUNT_TYPE="homed"
                break
                ;;
            *)
                echo "[ERROR] Invalid selection. Please choose 1 or 2."
                ;;
        esac
    done

    # 3. Home Directory Size (ONLY for systemd-homed)
    if [ "$ACCOUNT_TYPE" = "homed" ]; then
        echo
        while true; do
            read -p "Enter home directory quota size (e.g., 20G, 50G): " home_size
            home_size=$(echo "$home_size" | xargs)
        
            if [ -z "$home_size" ]; then
                echo "[ERROR] Home size cannot be empty for systemd-homed. Please try again."
                echo
                continue
            fi
        
            if ! [[ "$home_size" =~ ^[0-9]+[KMGT]?$ ]]; then
                echo "[ERROR] Invalid format. Please use format like: 5G, 20G, 1T, etc."
                echo
                continue
            fi
        
            HOME_SIZE="$home_size"
            break
        done
    fi

    # 4. Shell Selection
    clear
    echo "================================================="
    echo "              User Account Setup"
    echo "               Shell Selection"
    echo "================================================="
    echo
    mapfile -t shells < <(grep '^/bin/' /etc/shells)
    for i in "${!shells[@]}"; do
        shell_name=$(basename "${shells[$i]}")
        echo "$((i+1)). $shell_name (${shells[$i]})"
    done

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

    # 5. Sudoers Access
    clear
    echo "================================================="
    echo "              User Account Setup"
    echo "                   Sudoer"
    echo "================================================="
    echo
    if ask_yes_no "Add $User to sudoers file?"; then
        sudo_access="true"
    else
        sudo_access="false"
    fi

    # Write parameters out to user.conf for the chroot phase
    cat > /root/user.conf << EOF
USERNAME="$User"
ACCOUNT_TYPE="$ACCOUNT_TYPE"
HOME_SIZE="$HOME_SIZE"
SHELL="$Setshell"
SUDO_ACCESS="$sudo_access"
EOF
}

hostname_setup () {
    clear
    echo "================================================="
    echo "           System Configuration"
    echo "                 Hostname"
    echo "================================================="
    echo

    while true; do
        read -p "Enter hostname for this system: " Hostname
        Hostname=$(echo "$Hostname" | xargs)
    
        if [ -z "$Hostname" ]; then
            echo "[ERROR] Hostname cannot be empty. Please try again."
            echo
            continue
        fi
    
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
}

select_timezone() {
    clear
    echo "================================================="
    echo "           System Configuration"
    echo "             Region Selection"
    echo "================================================="
    echo
    regions=($(timedatectl list-timezones | cut -d'/' -f1 | sort -u))

    echo "Select your region:"
    select region in "${regions[@]}"; do
        [[ -n "$region" ]] && break
    done

    clear
    echo "================================================="
    echo "           System Configuration"
    echo "               City Selection"
    echo "================================================="
    echo
    cities=($(timedatectl list-timezones | grep "^$region/" | cut -d'/' -f2-))

    echo "Select your city:"
    select city in "${cities[@]}"; do
        [[ -n "$city" ]] && break
    done

    timezone="$region/$city"

    clear
    if ask_yes_no "Confirm timezone '$timezone'?"; then
        echo "Timezone confirmed: $timezone"
        SELECTED_TIMEZONE="$timezone"
    else
        echo "Okay, let's try again."
        select_timezone
    fi
}

select_locale() {
    if [[ -f /usr/share/i18n/SUPPORTED ]]; then
        mapfile -t locales < <(awk '{print $1}' /usr/share/i18n/SUPPORTED | grep -i "UTF-8" | sort -u)
    else
        mapfile -t locales < <(locale -a | grep -i "utf" | sort -u)
    fi

    local total_locales=${#locales[@]}
    local page_size=30
    local current_page=0
    local total_pages=$(( (total_locales + page_size - 1) / page_size ))

    while true; do
        clear
        echo "================================================="
        echo "           Locale Selection (Page $((current_page + 1)) of $total_pages)"
        echo "================================================="
        
        local start=$((current_page * page_size))
        local end=$((start + page_size))
        (( end > total_locales )) && end=$total_locales

        local page_items=("${locales[@]:start:page_size}")
        
        print_columns page_items $((start + 1))

        echo "-------------------------------------------------"
        echo " [N] Next Page   [P] Previous Page   [Q] Quit"
        echo " Enter the number of your selection."
        echo "-------------------------------------------------"

        read -p "Selection: " choice
        
        case ${choice,,} in
            n)
                if (( (current_page + 1) < total_pages )); then
                    ((current_page++))
                fi
                ;;
            p)
                if (( current_page > 0 )); then
                    ((current_page--))
                fi
                ;;
            q)
                return 1
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= total_locales )); then
                    SELECTED_LOCALE="${locales[choice-1]}"
                    clear
                    if ask_yes_no "Confirm '$SELECTED_LOCALE'?"; then
                        locale=$SELECTED_LOCALE
                        return 0
                    fi
                else
                    echo "Invalid input. Press Enter to continue..."
                    read -r
                fi
                ;;
        esac
    done
}

root_passwd() {
    clear
    echo "================================================="
    echo "               Root Password"
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
        fi
        if [ "$rootpw1" == "$rootpw2" ]; then
            break
        fi
    done
}

config_header() {
    clear
    echo "================================================="
    echo "              Installation Summary"
    echo "================================================="
    echo "           Configured System Information:"
    echo "Target Drive: $selected_drive"
    if [ "$selected_de" != "None" ]; then
        echo "Desktop Environment: $selected_de"
    fi
    echo "TimeZone: $timezone"
    echo "Locale: $locale"
    echo "          Configured User Information:"
    echo "Username: $User"
    echo "Home Size: $home_size"
    echo "Shell: $Setshell"
    echo "Sudo access: $sudo_access"
    echo "-------------------------------------------------"

    partitions=$(lsblk -ln -o NAME | grep "^$(basename "$selected_drive")" | grep -o '[0-9]*$')
    fdisk_cmd=""
    for p in $partitions; do
        fdisk_cmd+="d\n$p\n"
    done
    fdisk_cmd+="w\n"
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

detect_gpu_and_append_pkg() {
    gpu_info=$(lspci | grep -i 'vga\|3d\|2d')
    pkglist_file="pkglist.txt"

    if echo "$gpu_info" | grep -qi nvidia; then
        gpu_type="NVIDIA GPU detected."
        {
            echo "# GPU Drivers: NVIDIA"
            echo "nvidia-dkms"
            echo "nvidia-utils"
            echo "lib32-nvidia-utils"
            echo "nvidia-settings"
            echo "egl-wayland"
            echo
        } >> "$pkglist_file"

    elif echo "$gpu_info" | grep -qi amd; then
        gpu_type="AMD GPU detected."
        {
            echo "# GPU Drivers: AMD"
            echo "mesa"
            echo "lib32-mesa"
            echo "vulkan-radeon"
            echo "lib32-vulkan-radeon"
            echo "libva-mesa-driver"
            echo "mesa-vdpau"
            echo
        } >> "$pkglist_file"

    elif echo "$gpu_info" | grep -qi intel; then
        gpu_type="Intel integrated graphics detected."
        {
            echo "# GPU Drivers: Intel"
            echo "mesa"
            echo "lib32-mesa"
            echo "vulkan-intel"
            echo "lib32-vulkan-intel"
            echo "intel-media-driver"
            echo
        } >> "$pkglist_file"

    else
        gpu_type="No recognizable GPU found. Skipping package append."
    fi
}

detect_cpu_and_append_ucode() {
    cpu_vendor=$(lscpu | grep -i 'vendor' | awk '{print $NF}')
    pkglist_file="pkglist.txt"

    case "$cpu_vendor" in
        GenuineIntel)
            cpu_type="Intel CPU Detected"
            {
                echo "# CPU Microcode: Intel"
                echo "intel-ucode"
                echo
            } >> "$pkglist_file"
            ;;
        AuthenticAMD)
            cpu_type="AMD CPU Detected"
            {
                echo "# CPU Microcode: AMD"
                echo "amd-ucode"
                echo
            } >> "$pkglist_file"
            ;;
        *)
            cpu_type="Unknown CPU vendor. Skipping microcode package."
            ;;
    esac
}

detect_machine_type(){
    system_type=$(hostnamectl | grep "Chassis")
    if [[ $system_type == *"laptop"* ]]; then
        echo tlp >> pkglist.txt
    fi
}

validate_pkglist() {
    local pkgs=("$@")

    if [ ${#pkgs[@]} -eq 0 ]; then
        echo "❌ pkglist.txt contains no valid packages!" >&2
        return 1
    fi

    echo "Validating package targets against pacman databases..."
    local invalid_output
    if ! invalid_output=$(pacman -Sp "${pkgs[@]}" 2>&1 >/dev/null); then
        echo "❌ Package validation failed! The following issues were found:" >&2
        echo "$invalid_output" | grep "error: target not found:" >&2 || echo "$invalid_output" >&2
        return 1
    fi

    return 0
}

check_pacstrap() {
    local target="$1"

    local required_paths=(
        "$target/usr"
        "$target/etc"
        "$target/var"
        "$target/bin"
    )

    for p in "${required_paths[@]}"; do
        if [[ ! -e "$p" && ! -L "$p" ]]; then
            echo "❌ pacstrap incomplete: missing required path $p" >&2
            return 1
        fi
    done

    if [[ ! -d "$target/var/lib/pacman/local" ]]; then
        echo "❌ pacstrap incomplete: pacman DB missing at $target/var/lib/pacman/local" >&2
        return 1
    fi

    return 0
}

install_base_system() {
    local target="/mnt"
    local pkgs=()

    # Strip comments, replace non-breaking spaces (\xC2\xA0) with spaces, and read into array
    mapfile -t pkgs < <(awk '!/^#/ { gsub(/#.*/, ""); for(i=1;i<=NF;i++) print $i }' pkglist.txt)

    # Step 1: Dry-run check against sync DBs
    if ! validate_pkglist "${pkgs[@]}"; then
        return 1
    fi

    # Step 2: Run pacstrap
    pacstrap --needed "$target" "${pkgs[@]}" || return 1

    # Step 3: Run sanity checks
    check_pacstrap "$target" || return 1
}

gen_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

move_files_to_chroot() {
    mkdir -p /mnt/root
    cp /root/user.sh /mnt/root/user.sh
    cp /root/chroot_install.sh /mnt/root/chroot_install.sh
    cp /root/user.conf /mnt/root/user.conf
    cp /root/personalize.sh /mnt/root/personalize.sh
    cp /root/.net_config /mnt/root/.net_config
}

cleanup() {
    rm -f /mnt/root/chroot_install.sh
    rm -f /mnt/root/.net_config
    echo -n "Unmounting drive... "
    umount /mnt/boot
    umount /mnt
    swapoff "$selected_drive2"
}

network_config
drive_config
Desktop_Environment_Selection
hostname_setup
root_passwd
User_Config
select_timezone
select_locale
config_header
run_multiphase
phase_spinner "Enabling Multi-lib repo" sed -i -e '/#\[multilib\]/,+1s/^#//' /etc/pacman.conf
phase_spinner "Detecting GPU" detect_gpu_and_append_pkg
phase_spinner "Detecting CPU" detect_cpu_and_append_ucode
phase_spinner "Detecting Form Factor" detect_machine_type
phase_spinner "Optimizing Repo Mirror List" bash -c 'pacman -Sy && reflector --latest 200 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist'
phase_spinner "Updating Arch Linux Keyring" pacman -Sy archlinux-keyring --noconfirm
phase_spinner "Installing Base System" install_base_system
phase_spinner "Generating default fstab" gen_fstab
phase_spinner "Copying files to new system" move_files_to_chroot
phase_spinner "Configuring new system root..." arch-chroot /mnt /root/chroot_install.sh \
  "$selected_drive3" \
  "$selected_drive" \
  "$selected_drive1" \
  "$selected_drive2" \
  "$Hostname" \
  "$rootpw1" \
  "$timezone" \
  "$locale" \
  "$ACCOUNT_TYPE" \
  "$User" \
  "$Setshell" \
  "$sudo_access" \
  "$HOME_SIZE" \
  "$selected_de"
phase_spinner "Unmounting drive" cleanup
echo "System configured... Done."

if ask_yes_no "Reboot your system to setup user accounts! Would you like to restart now?"; then
    systemctl reboot
else
    exit
fi