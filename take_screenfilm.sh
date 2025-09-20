#!/usr/bin/env bash
set -euo pipefail

# Usage: take_screenfilm.sh [output_filename.mp4] [duration_seconds]
# Defaults: screenfilm.mp4, last 60 seconds
# Captures the most recent 5-second segments for pseudo-live recording

export DISPLAY=${DISPLAY:-:1}

# Parameters
output_file="${1:-/home/doofus/screenfilm.mp4}"
duration_seconds="${2:-60}"  # Default 60 seconds

recordings_dir="/home/doofus/recordings"
temp_dir=$(mktemp -d)

echo "Creating screenfilm from last $duration_seconds seconds using 5-second segments..."

# Find the most recent completed video files
# With 5-second segments, we get much more recent content
video_files=$(ls -t "$recordings_dir"/screen_*.mp4 2>/dev/null || echo "")

if [ -z "$video_files" ]; then
    echo "No video recordings found. Container may have just started."
    # Create a minimal placeholder video
    ffmpeg -y -f lavfi -i color=black:size=1024x768:duration=1 \
        -c:v libx264 -profile:v baseline -level 3.0 \
        -pix_fmt yuv420p -movflags +faststart \
        "$output_file" 2>/dev/null
    rm -rf "$temp_dir"
    echo "Created placeholder screenfilm (no recordings available yet)"
    exit 0
fi

# Build list of most recent files to get desired duration
# With 5-second segments, we need approximately duration_seconds/5 files
needed_segments=$(( (duration_seconds + 4) / 5 ))  # Round up
temp_list=$(mktemp)
total_duration=0
files_added=0

echo "Need approximately $needed_segments segments for ${duration_seconds}s"

# Add files in reverse chronological order (newest first for concat)
for video_file in $video_files; do
    # Skip if file doesn't exist or is empty
    if [ ! -f "$video_file" ] || [ ! -s "$video_file" ]; then
        continue
    fi
    
    # Get actual duration (should be ~5 seconds each)
    duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null || echo "5")
    duration_int=$(echo "$duration" | cut -d. -f1)  # Convert to integer
    
    if [ "$duration_int" -gt 0 ]; then
        # Insert at beginning of list to maintain chronological order
        temp_list_new=$(mktemp)
        echo "file '$video_file'" > "$temp_list_new"
        if [ -f "$temp_list" ]; then
            cat "$temp_list" >> "$temp_list_new"
        fi
        mv "$temp_list_new" "$temp_list"
        
        total_duration=$((total_duration + duration_int))
        files_added=$((files_added + 1))
        echo "Added: ${video_file} (~${duration_int}s)"
        
        # Stop if we have enough footage
        if [ "$total_duration" -ge "$duration_seconds" ] || [ "$files_added" -ge "$needed_segments" ]; then
            break
        fi
    fi
done

# Check if we have any files to process
if [ ! -s "$temp_list" ]; then
    echo "No usable video files found"
    ffmpeg -y -f lavfi -i color=black:size=1024x768:duration=1 \
        -c:v libx264 -profile:v baseline -level 3.0 \
        -pix_fmt yuv420p -movflags +faststart \
        "$output_file" 2>/dev/null
    rm -f "$temp_list"
    rm -rf "$temp_dir"
    echo "Created placeholder screenfilm"
    exit 0
fi

echo "Concatenating ${files_added} segments for ~${total_duration}s total"

# Create screenfilm with web-compatible settings
ffmpeg -y -f concat -safe 0 -i "$temp_list" \
    -c:v libx264 -profile:v baseline -level 3.0 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    -crf 23 \
    -preset medium \
    -t "$duration_seconds" \
    "$output_file" 2>/dev/null || {
    echo "Error: Failed to create screenfilm"
    rm -f "$temp_list"
    rm -rf "$temp_dir"
    exit 1
}

# Cleanup
rm -f "$temp_list"
rm -rf "$temp_dir"

echo "Screenfilm saved: $output_file (~${total_duration}s from ${files_added} segments)"
