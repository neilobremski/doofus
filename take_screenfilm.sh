#!/usr/bin/env bash
set -euo pipefail

# Usage: take_screenfilm.sh [output_filename.mp4] [duration_minutes]
# Defaults: screenfilm.mp4, last 2 minutes

export DISPLAY=${DISPLAY:-:1}

# Parameters
output_file="${1:-/home/doofus/screenfilm.mp4}"
duration_minutes="${2:-2}"

recordings_dir="/home/doofus/recordings"

echo "Creating screenfilm from last $duration_minutes minutes..."

# Find video files modified in the last N minutes
video_files=$(find "$recordings_dir" -name "screen_*.mp4" -mmin -"$duration_minutes" -type f | sort)

if [ -z "$video_files" ]; then
    echo "No recent screen recordings found in last $duration_minutes minutes."
    exit 1
fi

echo "Found video files:"
echo "$video_files"

# Create a temporary file list for ffmpeg concat
temp_list=$(mktemp)
for file in $video_files; do
    echo "file '$file'" >> "$temp_list"
done

# Convert to web-compatible MP4 using H.264 baseline profile
# This ensures compatibility with macOS and web browsers
ffmpeg -y -f concat -safe 0 -i "$temp_list" \
    -c:v libx264 -profile:v baseline -level 3.0 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    -crf 23 \
    -preset medium \
    "$output_file" 2>/dev/null || {
    echo "Error: Failed to create screenfilm"
    rm -f "$temp_list"
    exit 1
}

# Cleanup
rm -f "$temp_list"

echo "Screenfilm saved: $output_file"