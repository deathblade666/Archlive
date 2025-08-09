#!/bin/bash

source /root/user.conf

clear
homectl create "$USERNAME" --storage=luks --shell="$SHELL" --member-of=docker --disk-size="$HOME_SIZE" 

# Add to sudoers if requested
if [ "$SUDO_ACCESS" = true ]; then
    echo -n "Adding to sudoers... "
    if echo "$USERNAME ALL=(ALL:ALL) ALL" >> /etc/sudoers; then
        echo "Done."
    else
        echo "Failed!"
        echo "Warning: Failed to add user to sudoers."
    fi
fi

# Final cleanup
rm -f /etc/issue
mv /root/issue /etc/issue 2>/dev/null
systemctl disable first-boot.service
rm /etc/systemd/system/first-boot.service
systemctl unmask getty@tty1.service
systemctl enable getty@tty1.service

if [ -n "$DISPLAY_MANAGER" ]; then
    echo "Starting display manager ($DISPLAY_MANAGER)..."
    systemctl enable "$DISPLAY_MANAGER" --now
else 
    systemctl unmask getty@tty1.service
    systemctl enable getty@tty1.service --now
fi

rm /root/user.*


# # Phase Spinner
# phase_spinner() {
#     local message=$1
#     shift

#     echo -n "$message... "
#     "$@" &> /dev/null & local pid=$!

#     local spinstr='|/-\\'
#     local i=0

#     while kill -0 $pid 2>/dev/null; do
#         printf "\r%s... [%c]  " "$message" "${spinstr:i++%${#spinstr}:1}"
#         sleep 0.1
#     done

#     wait $pid
#     local exit_code=$?
#     printf "\r%s... Done.\n" "$message"
#     return $exit_code
# }

# # Helper function for yes/no prompts


# # Clear screen and show header
# user_account_creation_header(){
# clear
# echo "================================================="
# echo "           Arch Linux User Creation"
# echo "================================================="
# echo
# }
# # Get username
# user_account_creation_header
# while true; do
#     read -p "Enter username: " User
#     User=$(echo "$User" | xargs)  # Trim whitespace
    
#     if [ -z "$User" ]; then
#         echo "Username cannot be empty. Please try again."
#         continue
#     fi
    
#     # Check if user already exists
#     if id "$User" &>/dev/null; then
#         echo "User '$User' already exists. Please choose a different username."
#         continue
#     fi
    
#     break
# done

# # Get home directory size
# while true; do
#     user_account_creation_header
#     read -p "Enter home directory size (e.g., 5G, 500M, 10G): " home_size
#     home_size=$(echo "$home_size" | xargs)  # Trim whitespace
    
#     if [ -z "$home_size" ]; then
#         echo "Home size cannot be empty. Please try again."
#         continue
#     fi
    
#     # Validate format (number followed by K, M, G, or T)
#     if ! [[ "$home_size" =~ ^[0-9]+[KMGT]?$ ]]; then
#         echo "Invalid format. Please use format like: 5G, 500M, 1T, etc."
#         continue
#     fi
    
#     break
# done

# # Get list of valid shells
# user_account_creation_header
# echo
# echo "Available shells:"
# mapfile -t shells < <(grep '^/bin/' /etc/shells)
# for i in "${!shells[@]}"; do
#     shell_name=$(basename "${shells[$i]}")
#     echo "$((i+1)). $shell_name (${shells[$i]})"
# done

# # Get shell selection
# while true; do
#     read -p "Select shell (1-${#shells[@]}): " shell_choice
    
#     if ! [[ "$shell_choice" =~ ^[0-9]+$ ]] || [ "$shell_choice" -lt 1 ] || [ "$shell_choice" -gt "${#shells[@]}" ]; then
#         echo "Invalid selection. Please choose 1-${#shells[@]}."
#         continue
#     fi
    
#     Setshell="${shells[$((shell_choice-1))]}"
#     break
# done

# # Ask about sudo access
# user_account_creation_header
# echo
# if ask_yes_no "Add $User to sudoers file?"; then
#     sudo_access=true
# else
#     sudo_access=false
# fi

# # Desktop Environment setup

# de_header(){
# clear
# echo "================================================="
# echo "           Desktop Environment (Wayland)"
# echo "================================================="
# echo
# }

# de_header
# desktop_packages=""
# desktop_services=""
# selected_de=""

# echo "Available Wayland Desktop Environments:"
# echo "1. GNOME (Full-featured desktop with native Wayland support)"
# echo "2. KDE Plasma (Feature-rich desktop with excellent Wayland support)"
# echo "3. Sway (Wayland-based tiling window manager)"
# echo "4. Hyprland (Modern tiling compositor with animations)"
# echo "5. None (Command line only)"
# echo

# while true; do
#     read -p "Select desktop environment (1-5): " de_choice
    
#     case "$de_choice" in
#         1)
#             selected_de="GNOME"
#             desktop_packages="gnome gnome-extra"
#             desktop_services="gdm"
#             break
#             ;;
#         2)
#             selected_de="KDE Plasma"
#             desktop_packages="plasma-meta kde-applications"
#             desktop_services="sddm"
#             break
#             ;;
#         3)
#             selected_de="Sway"
#             desktop_packages="sway swayidle swaylock waybar foot grim slurp wl-clipboard"
#             desktop_services=""
#             break
#             ;;
#         4)
#             selected_de="Hyprland"
#             desktop_packages="hyprland waybar foot grim slurp wl-clipboard hyprpaper hypridle hyprlock"
#             desktop_services=""
#             break
#             ;;
#         5)
#             selected_de="None"
#             desktop_packages=""
#             desktop_services=""
#             break
#             ;;
#         *)
#             echo "[ERROR] Invalid selection. Please choose 1-5."
#             continue
#             ;;
#     esac
# done

# if [ "$selected_de" != "None" ]; then
#     de_header
#     install_desktop() {
#         pacman -S --noconfirm $desktop_packages
#     }
#     phase_spinner "Installing $selected_de desktop environment" install_desktop
    
#     if [ -n "$desktop_services" ]; then
#         enable_desktop_services() {
#             for service in $desktop_services; do
#                 systemctl enable "$service" 2>&1 | grep -vE 'Created symlink|is not a native service'
#             done
#         }
#         phase_spinner "Enabling desktop services" enable_desktop_services
#     fi
# else
#     echo "[INFO] No desktop environment selected. System will boot to command line."
# fi

# # Show summary
# clear
# echo
# echo "================================================="
# echo "           User Creation Summary"
# echo "================================================="
# echo "Username:     $User"
# echo "Home Size:    $home_size"
# echo "Shell:        $Setshell"
# echo "Sudo Access:  $([ "$sudo_access" = true ] && echo 'Yes' || echo 'No')"
# echo "Desktop Environment     $selected_de"
# echo "================================================="
# echo

# if ! ask_yes_no "Proceed with user creation?"; then
#     echo "User creation cancelled."
#     exit 0
# fi

# # Create user account
# clear
# echo
# echo "================================================="
# echo "           Creating $User Account"
# echo "================================================="
# echo

# echo "Creating user '$User'... "
# homectl create "$User" --storage=luks --shell="$Setshell" --member-of=docker --disk-size="$home_size"






# clear
# echo
# echo "================================================="
# echo "User account '$User' created successfully!"
# echo "================================================="
# echo

# if ask_yes_no "Would you like to log out now?"; then
#     echo "Logging out in 3 seconds..."
    
#     sleep 3
#     kill -HUP $PPID

# else
#     echo "User creation complete. You can now log in as '$User'."
# fi