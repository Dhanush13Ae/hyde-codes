#!/bin/bash

timestamp=$(date +%s)
rx=0
tx=0
cache="/tmp/.net_speed_cache"

# Get network interfaces, excluding virtual ones
interfaces=$(ls /sys/class/net 2>/dev/null | grep -Ev "lo|ipv6leak|docker|veth|br-|vmnet")

# Sum up bytes from all interfaces
for iface in $interfaces; do
    [ -r "/sys/class/net/$iface/statistics/rx_bytes" ] || continue
    r=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null) || continue
    t=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null) || continue
    rx=$((rx + r))
    tx=$((tx + t))
done

# Initialize cache if it doesn't exist
if [ ! -f "$cache" ]; then
    echo "$timestamp $rx $tx" > "$cache"
    echo '{"text": "󰈀 0B/s ↓ 0B/s ↑", "tooltip": "Waiting for next check..."}'
    exit 0
fi

# Read previous values
read last_time last_rx last_tx < "$cache" 2>/dev/null || {
    echo "$timestamp $rx $tx" > "$cache"
    echo '{"text": "󰈀 0B/s ↓ 0B/s ↑", "tooltip": "Error reading cache"}'
    exit 0
}

# Calculate deltas
delta_time=$((timestamp - last_time))
delta_rx=$((rx - last_rx))
delta_tx=$((tx - last_tx))

# Update cache
echo "$timestamp $rx $tx" > "$cache"

# Prevent division by zero
[ "$delta_time" -eq 0 ] && delta_time=1

# Calculate speeds
speed_rx=$((delta_rx / delta_time))
speed_tx=$((delta_tx / delta_time))

# Human readable function using pure bash arithmetic
hr() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        local gb_calc=$(( (bytes * 10) / 1073741824 ))
        local gb_int=$((gb_calc / 10))
        local gb_dec=$((gb_calc % 10))
        echo "${gb_int}.${gb_dec}GB/s"
    elif [ "$bytes" -ge 1048576 ]; then
        local mb_calc=$(( (bytes * 10) / 1048576 ))
        local mb_int=$((mb_calc / 10))
        local mb_dec=$((mb_calc % 10))
        echo "${mb_int}.${mb_dec}MB/s"
    elif [ "$bytes" -ge 1024 ]; then
        local kb_calc=$(( (bytes * 10) / 1024 ))
        local kb_int=$((kb_calc / 10))
        local kb_dec=$((kb_calc % 10))
        echo "${kb_int}.${kb_dec}KB/s"
    else
        echo "${bytes}B/s"
    fi
}

# Get top processes using network
top_procs=$(ss -tunap 2>/dev/null | grep -oP 'users:\(\(".*?",pid=\K[^,]+' | while read pid; do
    [ -f "/proc/$pid/comm" ] && cat "/proc/$pid/comm" 2>/dev/null
done | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s\n", $2}')

# Get vnstat data
get_vnstat_data() {
    if command -v vnstat &> /dev/null && command -v jq &> /dev/null; then
        data=$(vnstat --json 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$data" ]; then
            # Extract today's data
            today_rx=$(echo "$data" | jq -r '.interfaces[0].traffic.day | last | .rx' 2>/dev/null)
            today_tx=$(echo "$data" | jq -r '.interfaces[0].traffic.day | last | .tx' 2>/dev/null)
            
            # Extract monthly data
            month_rx=$(echo "$data" | jq -r '.interfaces[0].traffic.month | last | .rx' 2>/dev/null)
            month_tx=$(echo "$data" | jq -r '.interfaces[0].traffic.month | last | .tx' 2>/dev/null)
            
            # Handle empty values
            today_rx=${today_rx:-0}
            today_tx=${today_tx:-0}
            month_rx=${month_rx:-0}
            month_tx=${month_tx:-0}
            
            # Calculate totals
            today_total=$((today_rx + today_tx))
            month_total=$((month_rx + month_tx))
            
            # Format output
            echo "$(human_readable_vnstat $today_total)|$(human_readable_vnstat $month_total)"
        fi
    fi
}

# Human readable for vnstat (handles larger numbers)
human_readable_vnstat() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1048576 )); then
        awk "BEGIN {printf \"%.2f KiB\", $bytes/1024}"
    elif (( bytes < 1073741824 )); then
        awk "BEGIN {printf \"%.2f MiB\", $bytes/1048576}"
    else
        awk "BEGIN {printf \"%.2f GiB\", $bytes/1073741824}"
    fi
}

# Build tooltip
rx_human=$(hr $speed_rx)
tx_human=$(hr $speed_tx)
ICON_DOWN="<span foreground='#00ff88' rise='0'></span>"
ICON_UP="<span foreground='#ff4444' rise='0'> </span>"

tooltip="Download: $rx_human\\nUpload: $tx_human"

# Add top network users
if [ -n "$top_procs" ]; then
    tooltip="${tooltip}\\n\\nTop Network Users:"
    i=1
    while IFS= read -r proc; do
        [ -n "$proc" ] && tooltip="${tooltip}\\n${i}. $proc"
        i=$((i + 1))
    done <<< "$top_procs"
fi

# Add vnstat data if available
vnstat_data=$(get_vnstat_data)
if [ -n "$vnstat_data" ]; then
    today_usage=$(echo "$vnstat_data" | cut -d'|' -f1)
    month_usage=$(echo "$vnstat_data" | cut -d'|' -f2)
    
    tooltip="${tooltip}\\n\\nTotal Usage:"
    tooltip="${tooltip}\\nToday: ${today_usage}"
    tooltip="${tooltip}\\nMonth: ${month_usage}"
fi

# Output JSON
echo "{\"text\": \"$ICON_DOWN $rx_human $ICON_UP $tx_human\", \"tooltip\": \"$tooltip\"}"
