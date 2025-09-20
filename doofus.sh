#!/bin/bash

# Doofus Container Management Script
# Supports Ubuntu containers with browser automation capabilities

set -e

IMAGE_NAME="doofus"

# Function to get container name (only 'run' command accepts custom name)
get_container_name() {
    if [[ "$1" == "run" && -n "$2" ]]; then
        echo "$2"
    else
        echo "doofus"
    fi
}

CONTAINER_NAME=$(get_container_name "$1" "$2")

# Function to check if container exists and is running
container_running() {
    docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container exists (running or stopped)
container_exists() {
    docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to ensure container is running
ensure_running() {
    if ! container_running; then
        echo "Container '$CONTAINER_NAME' is not running. Starting it..."
        start_container
        sleep 5  # Give it time to fully start
    fi
}

# Function to build the image
build_image() {
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "Building Doofus image..."
        docker build -t "$IMAGE_NAME" .
    else
        echo "Image '$IMAGE_NAME' already exists."
    fi
}

# Function to start container
start_container() {
    build_image
    
    if container_running; then
        echo "Container '$CONTAINER_NAME' is already running."
        return 0
    fi
    
    if container_exists; then
        echo "Starting existing container '$CONTAINER_NAME'..."
        docker start "$CONTAINER_NAME"
    else
        echo "Creating and starting new container '$CONTAINER_NAME'..."
        docker run -d -p 5901:5901 -p 6080:6080 --name "$CONTAINER_NAME" "$IMAGE_NAME"
    fi
    
    echo "Container started!"
    echo "VNC: Connect to localhost:5901 (password: doofus)"
    echo "Web: http://localhost:6080/vnc.html"
}

# Function to convert normalized coordinates (0.0-1.0) to screen coordinates
translate_coords() {
    local norm_x=$1
    local norm_y=$2
    
    if [[ ! "$norm_x" =~ ^[0-9]*\.?[0-9]+$ ]] || [[ ! "$norm_y" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "Error: Coordinates must be decimal numbers between 0.0 and 1.0"
        exit 1
    fi
    
    ensure_running
    
    # Get screen resolution from container
    local screen_info=$(docker exec "$CONTAINER_NAME" xdotool getdisplaygeometry 2>/dev/null || echo "1024 768")
    local width=$(echo $screen_info | cut -d' ' -f1)
    local height=$(echo $screen_info | cut -d' ' -f2)
    
    local actual_x=$(echo "scale=0; $width * $norm_x / 1" | bc)
    local actual_y=$(echo "scale=0; $height * $norm_y / 1" | bc)
    
    echo "$actual_x $actual_y"
}

# Main command dispatcher
case "$1" in
    "build")
        echo "Building Doofus container..."
        docker build -t "$IMAGE_NAME" .
        ;;
        
    "run")
        CONTAINER_NAME=$(get_container_name "$1" "$2")
        echo "Running Doofus container with name '$CONTAINER_NAME'..."
        start_container
        ;;
        
    "start")
        echo "Starting Doofus container..."
        start_container
        ;;
        
    "stop")
        if container_running; then
            echo "Stopping container '$CONTAINER_NAME'..."
            docker stop "$CONTAINER_NAME"
            echo "Container stopped."
        else
            echo "Container '$CONTAINER_NAME' is not running."
        fi
        ;;
        
    "remove")
        if container_exists; then
            if container_running; then
                echo "Stopping container '$CONTAINER_NAME'..."
                docker stop "$CONTAINER_NAME"
            fi
            echo "Removing container '$CONTAINER_NAME'..."
            docker rm "$CONTAINER_NAME"
            echo "Container removed."
        else
            echo "Container '$CONTAINER_NAME' does not exist."
        fi
        ;;
        
    "click")
        button="${2:-1}"
        echo "Clicking mouse button $button..."
        ensure_running
        docker exec -u doofus "$CONTAINER_NAME" bash -c "DISPLAY=:1 xdotool click $button"
        ;;
        
    "do")
        if [ $# -lt 2 ]; then
            echo "Error: 'do' command requires xdotool arguments"
            echo "Usage: $0 do [xdotool_args...]"
            exit 1
        fi
        shift  # Remove 'do' from arguments
        echo "Executing xdotool: $@"
        ensure_running
        docker exec -u doofus "$CONTAINER_NAME" bash -c "DISPLAY=:1 xdotool $*"
        ;;
        
    "move")
        if [ $# -ne 3 ]; then
            echo "Error: 'move' command requires x and y coordinates (0.0 to 1.0)"
            echo "Usage: $0 move [x] [y]"
            exit 1
        fi
        coords=$(translate_coords "$2" "$3")
        x=$(echo $coords | cut -d' ' -f1)
        y=$(echo $coords | cut -d' ' -f2)
        echo "Moving cursor to normalized ($2, $3) = pixel ($x, $y)"
        ensure_running
        docker exec -u doofus "$CONTAINER_NAME" bash -c "DISPLAY=:1 xdotool mousemove $x $y"
        ;;
        
    "press")
        if [ $# -lt 2 ]; then
            echo "Error: 'press' command requires key(s) to press"
            echo "Usage: $0 press [key(s)]"
            exit 1
        fi
        shift  # Remove 'press' from arguments
        keys="$*"
        echo "Pressing keys: $keys"
        ensure_running
        docker exec -u doofus "$CONTAINER_NAME" bash -c "DISPLAY=:1 xdotool key $keys"
        ;;
        
    "type")
        if [ $# -lt 2 ]; then
            echo "Error: 'type' command requires text to type"
            echo "Usage: $0 type [text]"
            exit 1
        fi
        shift  # Remove 'type' from arguments
        text="$*"
        echo "Typing text: $text"
        ensure_running
        docker exec -u doofus "$CONTAINER_NAME" bash -c "DISPLAY=:1 xdotool type '$text'"
        ;;
        
    "translate")
        if [ $# -ne 3 ]; then
            echo "Error: 'translate' command requires x and y coordinates (0.0 to 1.0)"
            echo "Usage: $0 translate [x] [y]"
            exit 1
        fi
        coords=$(translate_coords "$2" "$3")
        echo "$coords"
        ;;
        
    "screenshot")
        filename="${2:-screenshot.png}"
        echo "Taking screenshot: $filename"
        ensure_running
        docker exec -u doofus "$CONTAINER_NAME" /home/doofus/take_screenshot.sh /home/doofus/screenshots/temp_screenshot.png
        docker cp "$CONTAINER_NAME:/home/doofus/screenshots/temp_screenshot.png" "$filename"
        echo "Screenshot saved as $filename"
        ;;
        
    "screenfilm")
        filename="${2:-screenfilm.mp4}"
        echo "Retrieving screen recordings: $filename"
        ensure_running
        
        # Get the last 2 video files from the recordings directory
        videos=$(docker exec -u doofus "$CONTAINER_NAME" bash -c "ls -t /home/doofus/recordings/screen_*.mp4 2>/dev/null | head -2" || echo "")
        
        if [ -z "$videos" ]; then
            echo "No screen recordings found."
            exit 1
        fi
        
        echo "Found recordings: $videos"
        
        # Copy videos to temporary location
        temp_dir=$(mktemp -d)
        video_list=""
        counter=1
        
        while IFS= read -r video; do
            if [ -n "$video" ]; then
                temp_file="$temp_dir/video_$counter.mp4"
                docker cp "$CONTAINER_NAME:$video" "$temp_file"
                video_list="$video_list -i $temp_file"
                counter=$((counter + 1))
            fi
        done <<< "$videos"
        
        # Concatenate videos if we have multiple
        if [ $counter -gt 2 ]; then
            echo "Concatenating $(($counter - 1)) video segments..."
            ffmpeg -y $video_list -filter_complex concat=n=$(($counter - 1)):v=1:a=0 "$filename" 2>/dev/null
        else
            # Just copy the single video
            cp "$temp_dir/video_1.mp4" "$filename"
        fi
        
        # Cleanup
        rm -rf "$temp_dir"
        echo "Screen recording saved as $filename"
        ;;
        
    "logs")
        ensure_running
        docker logs "$CONTAINER_NAME"
        ;;
        
    *)
        echo "Doofus Container Management"
        echo "Usage: $0 {command} [options]"
        echo ""
        echo "Commands:"
        echo "  build                          - Build the Docker image"
        echo "  run [name]                     - Run container with optional name (default: doofus)"
        echo "  start                          - Build and start the container"
        echo "  stop                           - Stop the container"
        echo "  remove                         - Remove the container"
        echo "  click [button]                 - Click mouse button (1=left, 2=middle, 3=right)"
        echo "  do [xdotool_args...]          - Execute xdotool with specified arguments"
        echo "  move [x] [y]                  - Move cursor to normalized coordinates (0.0-1.0)"
        echo "  press [key(s)]                - Simulate pressing keys (e.g., 'ctrl+c')"
        echo "  type [text]                   - Type text using keyboard simulation"
        echo "  translate [x] [y]             - Translate normalized coordinates to pixels"
        echo "  screenshot [filename]         - Take screenshot (default: screenshot.png)"
        echo "  screenfilm [filename]         - Get last 2 minutes of recording (default: screenfilm.mp4)"
        echo "  logs                          - View container logs"
        echo ""
        echo "Access:"
        echo "  VNC: localhost:5901 (password: doofus)"
        echo "  Web: http://localhost:6080/vnc.html"
        ;;
esac
