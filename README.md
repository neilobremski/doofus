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
- screenfilm [filename] [secs]: Create a precisely-timed MP4 from the last N seconds of screen activity (default 60s). Output files are saved to the host-accessible recordings/exports/ directory.
- screenshot [filename]: Take a screenshot within the container and save it as [filename] which defaults to screenshot.png.
- start: Build and run the Docker image as a container named "doofus". If it's already running then this will be a no-op.
- stop: Stop the Docker container if it's running
- restart: Stop, remove, rebuild the image, and start the container (useful after image changes)
- translate [x] [y]: translate 0.0 to 1.0 coordinate values into screen coordinates for the container (`translate 1 1` would give you the desktop size)
- type [text]: simulates a keyboard typing the [text] using xdotool

## Contents

The Doofus docker image is built based on Ubuntu 24.04 with the following pre-installed:

- Firefox Web Browser (installed via Mozillateam PPA to avoid snap in containers, available in Applications menu)
- FFMPEG: continually recording the desktop
- xdotool: automating mouse and keyboard interaction
- xvfb: X Windows virtual frame buffer display
- scrot: taking screenshots
- supervisor: low-level services controller
- NoVNC and TigerVNC: remote viewing
- XFCE4: desktop window manager

## Screenshots

The `take_screenshot.sh` script is included in the container and provides reliable screenshot functionality. It tries multiple screenshot tools in order of preference (scrot, xfce4-screenshooter, ImageMagick's import) and automatically creates the necessary directory structure.

Screenshots taken via the `doofus.sh screenshot` command are saved to the host machine with the specified filename (default: screenshot.png).

## Screen Recording

FFMPEG records the desktop continually using 5-second segments (pseudo-live). The `screenfilm` command concatenates the most recent completed segments and creates precisely-timed MP4 files.

- Segment duration: 5 seconds
- Default capture window: 60 seconds (configurable)
- Retention: last ~10 minutes of segments
- Mouse cursor: rendered onto the desktop by x11vnc, so it appears in both screenshots and videos
- **New**: Volume mapping exposes recordings directory to host for debugging
- **Fixed**: Accurate duration trimming - output videos are exactly the requested length

### Volume Mapping for Recordings

The recordings directory is now mapped to the host filesystem, allowing you to:
- Inspect raw 5-second segments directly: `ls -la recordings/`
- Access generated screenfilms at: `recordings/exports/filename.mp4`
- Debug recording issues by examining segment files

Set the host recordings directory with the `DOOFUS_RECORDINGS_DIR` environment variable:
```bash
export DOOFUS_RECORDINGS_DIR="$HOME/doofus-recordings"
./doofus.sh start
```

Defaults to `./recordings` in the current directory.

## Installation

You can install a global `doofus` command so you can run it from anywhere.

Option A: Symlink (recommended)

```
sudo ln -sf "doofus.sh" /usr/local/bin/doofus
```

Option B: Shell alias

Add this to your shell profile (~/.zshrc or ~/.bashrc):
```
alias doofus="doofus.sh"
```
Then reload your shell: `source ~/.zshrc` or `source ~/.bashrc`.

Note: The script now builds the Docker image from its own repository directory, so you can run `doofus` from any working directory.

## Troubleshooting

**Firefox fails to launch:**
- Ensure the container has started properly with XFCE4 desktop environment
- Check that dbus-x11 is installed (included in the image)
- Verify DISPLAY environment variable is set to :1

**Screenshots fail:**
- The image includes scrot as the primary screenshot tool
- Fallbacks include xfce4-screenshooter and ImageMagick's import command
- Ensure the container is running with display :1 active
