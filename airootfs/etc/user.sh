#!/bin/bash

# Get list of valid shells from /etc/shells
mapfile -t shells < <(grep -E '^/' /etc/shells)

# Prompt for user name
read -p "Enter user name: " User

# prompt for home size
read -p "Enter amount you'd like to dedicate to "$user"'s home (example 5G for 5GBs)" home_size

# Load only shells that reside in /bin
mapfile -t shells < <(grep '^/bin/' /etc/shells)

# Display shell options
echo "Select default shell:"
for i in "${!shells[@]}"; do
  printf "%d) %s\n" "$((i+1))" "${shells[$i]}"
done

# Read shell selection
read -p "Enter the number of your choice [1]: " shell_choice
shell_choice=${shell_choice:-1}
Setshell="${shells[$((shell_choice-1))]}"


# Ask about sudo access
read -p "Add $User to sudoers file? [Y/n]: " Allthethings
Allthethings=${Allthethings:-Y}

if [[ "$Allthethings" =~ ^[Yy]$ ]]; then
  echo "$User ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

# Create the user
homectl create "$User" --storage=luks --shell="$Setshell" --member-of=docker --disk-size="$home_size"

rm /etc/issue
mv /root/issue /etc/issue
clear
echo User Account created! 
echo logout and login with your new user.