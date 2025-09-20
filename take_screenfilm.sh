#!/usr/bin/env bash
set -euo pipefail

# Usage: take_screenfilm.sh [output_filename.mp4] [duration_seconds]
# Defaults: screenfilm.mp4, last 90 seconds
# Captures the most recent completed segments PLUS the active recording buffer

export DISPLAY=${DISPLAY:-:1}

# Parameters
output_file="${1:-/home/doofus/screenfilm.mp4}"
duration_seconds="${2:-90}"  # Default 90 seconds (1.5 minutes)

recordings_dir="/home/doofus/recordings"
temp_dir=$(mktemp -d)

echo "Creating screenfilm from last $duration_seconds seconds..."

# Find the most recent completed video files (not currently being written to)
# Sort by modification time, newest first (use ls -t for portability)
video_files=$(ls -t "$recordings_dir"/screen_*.mp4 2>/dev/null || echo "")

# Get current ffmpeg PID to identify active recording
active_recording=""
ffmpeg_pid=$(pgrep -f "ffmpeg.*screen_.*mp4" | head -1 || echo "")
if [ -n "$ffmpeg_pid" ]; then
    # Find which file ffmpeg is currently writing to
    active_file=$(lsof -p "$ffmpeg_pid" 2>/dev/null | grep "screen_.*\.mp4" | awk '{print $NF}' | head -1)
    if [ -n "$active_file" ] && [ -f "$active_file" ]; then
        active_recording="$active_file"
        echo "Found active recording: $active_recording"
    fi
fi

# Build list of files to concatenate
concat_files=""
total_duration=0
temp_list=$(mktemp)

# Function to get video duration in seconds
get_duration() {
    ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null || echo "0"
}

# First, add the active recording if it exists and has content
if [ -n "$active_recording" ] && [ -s "$active_recording" ]; then
    duration=$(get_duration "$active_recording")
    if (( $(echo "$duration > 1" | bc -l) )); then
        echo "file '$active_recording'" >> "$temp_list"
        total_duration=$(echo "$total_duration + $duration" | bc -l)
        echo "Added active recording: ${active_recording} (${duration}s)"
    fi
fi

# Then add completed recordings in reverse chronological order until we reach desired duration
for video_file in $video_files; do
    # Skip the active recording file if we already added it
    if [ "$video_file" = "$active_recording" ]; then
        continue
    fi
    
    # Skip if file doesn't exist or is empty
    if [ ! -s "$video_file" ]; then
        continue
    fi
    
    duration=$(get_duration "$video_file")
    if (( $(echo "$duration > 0" | bc -l) )); then
        # Insert at beginning of list (reverse chronological order for playback)
        temp_list_new=$(mktemp)
        echo "file '$video_file'" > "$temp_list_new"
        cat "$temp_list" >> "$temp_list_new"
        mv "$temp_list_new" "$temp_list"
        
        total_duration=$(echo "$total_duration + $duration" | bc -l)
        echo "Added completed recording: ${video_file} (${duration}s)"
        
        # Stop if we have enough footage
        if (( $(echo "$total_duration >= $duration_seconds" | bc -l) )); then
            break
        fi
    fi
done

# Check if we have any files to process
if [ ! -s "$temp_list" ]; then
    echo "No video recordings found or all files are empty. Container may have just started."
    # Create a minimal placeholder video
    ffmpeg -y -f lavfi -i color=black:size=1024x768:duration=1 \
        -c:v libx264 -profile:v baseline -level 3.0 \
        -pix_fmt yuv420p -movflags +faststart \
        "$output_file" 2>/dev/null
    rm -f "$temp_list"
    rm -rf "$temp_dir"
    echo "Created placeholder screenfilm (no recordings available yet)"
    exit 0
fi

echo "Total duration: ${total_duration}s from $(wc -l < "$temp_list") files"

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

echo "Screenfilm saved: $output_file (${total_duration}s captured)"
