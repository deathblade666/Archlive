#!/bin/sh

dbus-update-activation-environment --systemd DISPLAY &
numlockx &
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh) &
export SSH_AUTH_SOCK &
xset s off &
export _JAVA_AWT_WM_NONREPARENTING=1
session=${1:-dwm}

case $session in 
    dwm	    ) exec /usr/local/bin/dwm;;
    qtile   ) exec qtile start;;
    *	    ) exec$1;;
esac
