#!/bin/bash

source /root/user.conf

rfkill unblock all
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

sleep 2
clear
homectl create "$USERNAME" --storage=luks --shell="$SHELL" --member-of=docker --disk-size="$HOME_SIZE" 

# Add to sudoers if requested
if [ "$SUDO_ACCESS" = true ]; then
    echo -n "Adding $USERNAME to sudoers... "
    if echo "$USERNAME ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/root_perm_$USERNAME"; then
        chmod 440 "/etc/sudoers.d/root_perm_$USERNAME"
        echo "Done."
    else
        echo "Failed!"
    fi
fi

TARGET_SCRIPT="/root/personalize.sh"

# Check if the file exists
if [[ -f "$TARGET_SCRIPT" ]]; then
    chmod +x $TARGET_SCRIPT
fi


# Final cleanup
systemctl disable first-boot.service
rm /etc/systemd/system/first-boot.service

if [ -n "$DISPLAY_MANAGER" ]; then
    echo "Starting display manager ($DISPLAY_MANAGER)..."
    systemctl unmask getty@tty1.service
    systemctl enable getty@tty1.service
    systemctl enable "$DISPLAY_MANAGER" --now
else 
    systemctl unmask getty@tty1.service
    systemctl enable getty@tty1.service --now
fi

rm /root/user.*
