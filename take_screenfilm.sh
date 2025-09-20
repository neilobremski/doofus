#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <output_mp4_path> <seconds>" >&2
  exit 2
}

OUT="${1:-}"
WANTED="${2:-}"

[[ -z "${OUT}" || -z "${WANTED}" ]] && usage
if ! [[ "${WANTED}" =~ ^[0-9]+$ ]] || (( WANTED <= 0 )); then
  echo "Seconds must be a positive integer" >&2
  exit 2
fi

REC_DIR="${SCREENFILM_DIR:-/home/doofus/recordings}"
SEGMENT_SECONDS="${SCREENFILM_SEGMENT_SECONDS:-5}"
SEGMENT_GLOB="${SCREENFILM_SEGMENT_GLOB:-*.mp4}"

if [[ ! -d "${REC_DIR}" ]]; then
  echo "Recordings directory not found: ${REC_DIR}" >&2
  exit 1
fi

# Find segments, sorted chronologically by mtime (Linux compatible)
mapfile -t ordered < <(
  find "${REC_DIR}" -maxdepth 1 -type f -name "${SEGMENT_GLOB}" -exec stat -c "%Y %n" {} \; \
  | sort -n \
  | awk '{ $1=""; sub(/^ /,""); print }'
)

L=${#ordered[@]}
if (( L == 0 )); then
  echo "No segment files found in ${REC_DIR} matching ${SEGMENT_GLOB}" >&2
  # Create a short placeholder video if no segments exist
  if [[ "${OUT}" != /* ]]; then
    mkdir -p "${REC_DIR}/exports"
    OUT="${REC_DIR}/exports/${OUT}"
  fi
  mkdir -p "$(dirname "${OUT}")"
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i color=black:size=1024x768:duration=1 \
    -c:v libx264 -preset veryfast -pix_fmt yuv420p -movflags +faststart "${OUT}"
  echo "Created placeholder video (no recordings available yet): ${OUT}"
  exit 0
fi

# How many 5s segments are needed to cover WANTED seconds
need=$(( (WANTED + SEGMENT_SECONDS - 1) / SEGMENT_SECONDS ))

# Take the last 'need' segments (chronological order retained)
start=0
if (( need < L )); then
  start=$(( L - need ))
fi
selected=( "${ordered[@]:${start}}" )
K=${#selected[@]}

total=$(( K * SEGMENT_SECONDS ))
offset=0
if (( total > WANTED )); then
  offset=$(( total - WANTED ))  # Start this many seconds into the concat so we end "now"
fi

# If OUT is relative, place it under the recordings mount so the host can access it
if [[ "${OUT}" != /* ]]; then
  mkdir -p "${REC_DIR}/exports"
  OUT="${REC_DIR}/exports/${OUT}"
fi
mkdir -p "$(dirname "${OUT}")"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
list="${tmpdir}/concat.txt"
: > "${list}"

# Build ffmpeg concat list, safely escaping single quotes
for p in "${selected[@]}"; do
  esc="${p//\'/\'\\\'\'}"
  printf "file '%s'\n" "${esc}" >> "${list}"
done

# Concat and precisely trim to the last WANTED seconds.
# -ss after -i for accurate seek, end aligned with newest frames because offset+WANTED = total
ffmpeg -hide_banner -loglevel error \
  -f concat -safe 0 -i "${list}" \
  -ss "${offset}" -t "${WANTED}" \
  -map 0:v:0 -map 0:a:0? \
  -c:v libx264 -preset veryfast -pix_fmt yuv420p \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  -y "${OUT}"

# Optional: report duration if ffprobe exists
if command -v ffprobe >/dev/null 2>&1; then
  dur="$(ffprobe -v error -show_entries format=duration -of default=nokey=1:nokey=1:noprint_wrappers=1 "${OUT}" 2>/dev/null || true)"
  if [[ -n "${dur}" ]]; then
    printf "Wrote %s (%.2fs)\n" "${OUT}" "${dur}"
  else
    echo "Wrote ${OUT}"
  fi
else
  echo "Wrote ${OUT}"
fi
