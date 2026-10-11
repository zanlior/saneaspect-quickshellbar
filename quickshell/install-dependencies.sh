#!/usr/bin/env bash
set -euo pipefail
# Run this yourself in a terminal so sudo can ask for your password.
sudo pacman -S --needed quickshell python python-dbus python-gobject networkmanager bluez bluez-utils pipewire-pulse wireplumber playerctl brightnessctl hyprsunset hyprlock ddcutil ttf-jetbrains-mono-nerd
printf 'The interface uses Rubik; install that font if it is not already available.\n'
printf 'Wallpaper picker uses your existing awww daemon, or swww.\n'
