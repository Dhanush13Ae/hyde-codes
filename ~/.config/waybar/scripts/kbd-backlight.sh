#!/bin/bash

device="asus::kbd_backlight"
current=$(brightnessctl --device="$device" get)
max=$(brightnessctl --device="$device" max)

# Icon array for levels 0-3
icons=("" "󰪠" "󰪢" "󰪥")

# Get the icon for current level
icon="${icons[$current]}"

# Output format for Waybar
echo "{\"text\": \"$icon $current\", \"tooltip\": \"Keyboard Backlight Level: $current/$max\", \"class\": \"level-$current\"}"
