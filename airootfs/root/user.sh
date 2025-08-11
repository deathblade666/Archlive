#!/bin/bash

source /root/user.conf

ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

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