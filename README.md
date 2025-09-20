# Doofus

A minimal Ubuntu container with a browser and basic automation capabilities for driving by AI.

## Usage

The doofus.sh drives everything from building and running the Docker image to executing commands for it to perform.

- build: Build the Docker image if it doesn't already exist
- run [name]: Run the Docker image with an optional container name that defaults to "doofus"
- click [button]: clicks the mouse where [button] is the xdotool equivalent (1=left, 2=middle, 3=right) 
- do [...args]: execute xdotool with the specified arguments.
- move [x] [y]: move mouse cursor to coordinates expressed in the 0.0 to 1.0 range (translated to fixed screen coordinates)
- press [key(s)]: simulate pressing special keys, like CTRL+C, etc.
- remove: remove the Docker container
- screenfilm [filename]: Retrieve the last 2 FFMPEG screen recordings (up to 2 minutes) and save them as [filename].
- screenshot [filename]: Take a screenshot within the container and save it as [filename] which defaults to screenshot.png.
- start: Build and run the Docker image as a container named "doofus". If it's already running then this will be a no-op.
- stop: Stop the Docker container if it's running
- translate [x] [y]: translate 0.0 to 1.0 coordinate values into screen coordinates for the container (`translate 1 1` would give you the desktop size)
- type [text]: simulates a keyboard typing the [text] using xdotool

## Contents

The Doofus docker image is built based on Ubuntu 24.04 with the following pre-installed:

- Chromium Web Browser
- FFMPEG: continually recording the desktop
- xdotool: automating mouse and keyboard interaction
- xvfb: X Windows virtual frame buffer display
- scrot: taking screenshots
- supervisor: low-level services controller
- NoVNC and TigerVNC: remote viewing
- XFCE4: desktop window manager

## Screen Recording

FFMPEG is configured to record the desktop continually while the container is running to be able to observe what has happened while driving the automation. This is setup to create a new video every 60 seconds and delete videos older than 1 hour.
