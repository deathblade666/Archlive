# My Arch installation media
-----------------------------------------------------------------------------

## Key Features

1. systemd driven
    - ~~systemd-networkd~~ for compatibility switched to NetworkManager
    - systemd-resolved
    - systemd-homed
      - home dir encryption with LUKS
2. easily add your desired packages!
    - modify the pklist.txt to suite your needs
    - can include comments denoted by ``#`` for organization
3. compositor selection menu
4. setup wifi during install
5. minimal install
    - only a handful of applications are installed out the box
6. Linux-Zen kernel for increase responsiveness
7. btrfs ``/`` partition by default

## Furture Improvments
- [ ] custom partition
    - currently its set to a default of 
      - 1GB EFI
      - 4 GB swap
      - BTRFS ``/``
        - ext4 Home (encrypted with LUKS)
- [ ] Customization script (WIP)


## Instructions

- Download iso from github
- write to bootable media
- once the live disk is loaded just run ``./install.sh`` 

## Build
  archiso is required and can be installed by running one of the following commands
  
  pacman install
  
  ``` sudo pacman -S archiso ```
  
  yay install
  
  ``` yay -S archiso-git ```
  
  Once it is installed you can clone this repo with the following command
``` git clone https://github.com/deathblade666/Archlive.git ~/archlive ```

For more information on archiso please visit https://wiki.archlinux.org/index.php/Archiso or the develpments homepage at https://gitlab.archlinux.org/archlinux/archiso/-/tree/master/docs
