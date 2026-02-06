#!/bin/bash

# Get vnstat data in json format
data=$(vnstat --json)

# Extract today's data (last entry in day array is today)
today_rx=$(echo "$data" | jq -r '.interfaces[0].traffic.day | last | .rx')
today_tx=$(echo "$data" | jq -r '.interfaces[0].traffic.day | last | .tx')

# Extract monthly data (last entry in month array is current month)
month_rx=$(echo "$data" | jq -r '.interfaces[0].traffic.month | last | .rx')
month_tx=$(echo "$data" | jq -r '.interfaces[0].traffic.month | last | .tx')

# Calculate totals (handle empty values)
today_rx=${today_rx:-0}
today_tx=${today_tx:-0}
month_rx=${month_rx:-0}
month_tx=${month_tx:-0}

today_total=$((today_rx + today_tx))
month_total=$((month_rx + month_tx))

# Function to convert bytes to human readable format
human_readable() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1048576 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KiB"
    elif (( bytes < 1073741824 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}") MiB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}") GiB"
    fi
}

# Format the data
today_formatted=$(human_readable $today_total)
month_formatted=$(human_readable $month_total)

# Output in waybar format
echo "{\"text\":\"\",\"tooltip\":\"Today: ${today_formatted}\\nMonth: ${month_formatted}\"}"
