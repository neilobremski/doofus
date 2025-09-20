#!/usr/bin/env bash
set -euo pipefail

# Usage: take_screenshot.sh [filename.png]
# If no filename is provided, uses temp_screenshot.png

export DISPLAY=${DISPLAY:-:1}

# Use the provided filename or default
filename="${1:-temp_screenshot.png}"

# Ensure the directory exists
mkdir -p "$(dirname "$filename")"

# Try different screenshot tools in order of preference, always include cursor
if command -v scrot >/dev/null 2>&1; then
    scrot --pointer "$filename"
elif command -v xfce4-screenshooter >/dev/null 2>&1; then
    xfce4-screenshooter -f -m -s "$filename"
elif command -v import >/dev/null 2>&1; then
    import -window root "$filename"
else
    echo "Error: No screenshot tool available. Install scrot, xfce4-screenshooter, or ImageMagick."
    exit 1
fi

echo "Screenshot saved: $filename"