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
playlist="$recordings_dir/segments.m3u8"
temp_dir=$(mktemp -d)

echo "Creating screenfilm from last $duration_seconds seconds using 5-second segments..."

# Use the generated playlist to determine the most recent, completed segments
# Fallback to plain ls if playlist doesn't exist yet

# Determine how many segments are needed (roughly)
needed_segments=$(( (duration_seconds + 4) / 5 ))

# Build a list of "duration path" lines
build_pairs() {
  if [ -f "$playlist" ]; then
    awk 'prev ~ /^#EXTINF:/ { d=prev; gsub(/^#EXTINF:/,"",d); gsub(",","",d); print d " " $0 } { prev=$0 }' "$playlist" | sed -E "s#([^ ]+) (.+)#\1 $recordings_dir/\2#"
  else
    for f in $(ls -t "$recordings_dir"/screen_*.mp4 2>/dev/null || true); do
      [ -f "$f" ] || continue
      dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null || echo 5)
      echo "$dur $f"
    done
  fi
}

pairs_lines=$(build_pairs || true)
if [ -z "$pairs_lines" ]; then
  echo "No video recordings found. Container may have just started."
  ffmpeg -y -f lavfi -i color=black:size=1024x768:duration=1 \
    -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p -movflags +faststart \
    "$output_file" 2>/dev/null
  rm -rf "$temp_dir"
  echo "Created placeholder screenfilm (no recordings available yet)"
  exit 0
fi

# Take last N lines (most recent), then reverse to chronological order
selected_lines=$(printf "%s\n" "$pairs_lines" | tail -n "$needed_segments")
chronological=$(printf "%s\n" "$selected_lines" | tac)

# Prepare ffconcat list with per-file durations for debugging
list_file=$(mktemp)
echo "ffconcat version 1.0" > "$list_file"

actual_total=0
count=0

echo "Segments to concatenate (duration seconds | size bytes | path):"
# Build ffconcat list and debug lines; stop when enough seconds accumulated
current_total=0
printf "%s\n" "$chronological" | while read -r dur path; do
  [ -f "$path" ] || continue
  size=$(wc -c < "$path" 2>/dev/null || echo 0)
  echo "  + $dur | $size | $path"
  echo "file '$path'" >> "$list_file"
  dur_int=${dur%.*}
  if [ -z "$dur_int" ]; then dur_int=5; fi
  current_total=$((current_total + dur_int))
  # Write a stopper marker when we've hit our target window; the following awk will trim
  if [ "$current_total" -ge "$duration_seconds" ]; then
    echo "#STOP" >> "$list_file"
    break
  fi
done
# Trim list_file at STOP (if present) and compute counts
if grep -q '^#STOP$' "$list_file"; then
  awk '{print} /^#STOP$/ { exit }' "$list_file" > "$list_file.trim" && mv "$list_file.trim" "$list_file"
fi
count=$(grep -c '^file ' "$list_file" || true)
# Approximate total seconds by counting segments (5s each) if playlist durations aren't trusted
actual_total=$((count * 5))

echo "Concatenating $count segments for ~${actual_total}s total"

# Concatenate and re-encode to a web-friendly MP4
ffmpeg -y -f concat -safe 0 -i "$list_file" \
  -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p \
  -movflags +faststart -crf 23 -preset medium \
  "$output_file" 2>/dev/null || {
  echo "Error: Failed to create screenfilm"
  rm -f "$list_file"; rm -rf "$temp_dir"
  exit 1
}

rm -f "$list_file"; rm -rf "$temp_dir"

echo "Screenfilm saved: $output_file (~${actual_total}s from $count segments)"
