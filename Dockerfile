FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install system dependencies and Firefox
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        gnupg2 \
        ca-certificates \
        apt-transport-https \
        software-properties-common && \
    add-apt-repository -y ppa:mozillateam/ppa && \
    printf 'Package: firefox\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' | tee /etc/apt/preferences.d/mozillateamppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        tigervnc-standalone-server \
        tigervnc-common \
        xfce4 \
        xfce4-terminal \
        dbus-x11 \
        supervisor \
        novnc \
        websockify \
        imagemagick \
        xdotool \
        scrot \
        ffmpeg \
        dmz-cursor-theme \
        xcursor-themes \
        firefox \
        lsof \
        bc && \
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox 200 && \
    update-alternatives --set x-www-browser /usr/bin/firefox && \
    rm -rf /var/lib/apt/lists/*

# Set cursor environment variables globally for large, visible cursor
ENV XCURSOR_THEME=DMZ-White
ENV XCURSOR_SIZE=48
ENV DISPLAY=:1
ENV BROWSER=firefox

# Create a non-root user
RUN useradd -m -s /bin/bash doofus && \
    echo "doofus:doofus" | chpasswd

# Set up VNC (we'll use x11vnc's -passwd option instead of stored password)
RUN mkdir -p /home/doofus/.vnc && \
    chown -R doofus:doofus /home/doofus/.vnc

# Create directories
RUN mkdir -p /home/doofus/screenshots /home/doofus/recordings && \
    chown -R doofus:doofus /home/doofus/screenshots /home/doofus/recordings

# Configure cursor theme for the doofus user
RUN mkdir -p /home/doofus/.icons/default && \
    echo "[Icon Theme]" > /home/doofus/.icons/default/index.theme && \
    echo "Inherits=DMZ-White" >> /home/doofus/.icons/default/index.theme && \
    chown -R doofus:doofus /home/doofus/.icons

# Configure XFCE4 to disable screensaver (Firefox will be available in applications menu)
RUN mkdir -p /home/doofus/.config/xfce4/xfconf/xfce-perchannel-xml && \
    chown -R doofus:doofus /home/doofus/.config

# Create XFCE4 screensaver configuration to disable screensaver/blank screen
RUN cat > /home/doofus/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml << 'SCREENSAVER_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="mode" type="int" value="0"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
SCREENSAVER_EOF

# Create XFCE4 power manager configuration to prevent screen blanking
RUN cat > /home/doofus/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml << 'POWER_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="dpms-on-battery-sleep" type="uint" value="0"/>
    <property name="dpms-on-battery-off" type="uint" value="0"/>
  </property>
</channel>
POWER_EOF

# Let XFCE use default panel configuration - custom config was causing display issues

# Set ownership of config files
RUN chown -R doofus:doofus /home/doofus/.config

# Create FFMPEG recording script
RUN cat > /home/doofus/start_recording.sh << 'FFMPEG_EOF'
#!/bin/bash
export DISPLAY=:1

# Create recordings directory
mkdir -p /home/doofus/recordings

# Start continuous screen recording with 5-second segments for pseudo-live capture
ffmpeg -y -f x11grab -r 10 -s 1024x768 -i :1.0 \
  -c:v libx264 -preset ultrafast -crf 23 \
  -f segment -segment_time 5 -segment_format mp4 \
  -segment_list /home/doofus/recordings/segments.m3u8 \
  -segment_list_flags +live \
  -reset_timestamps 1 \
  /home/doofus/recordings/screen_%03d.mp4 &

# Cleanup old recordings (keep last 10 minutes with 5-second segments)
while true; do
  sleep 60  # Check every minute
  find /home/doofus/recordings -name "screen_*.mp4" -mmin +10 -delete 2>/dev/null || true
done &
FFMPEG_EOF

RUN chmod +x /home/doofus/start_recording.sh && \
    chown doofus:doofus /home/doofus/start_recording.sh

# Create cursor initialization script
RUN cat > /home/doofus/init_cursor.sh << 'CURSOR_INIT_EOF'
#!/bin/bash
export DISPLAY=:1
export XCURSOR_THEME=DMZ-White
export XCURSOR_SIZE=48

# Disable screensaver and DPMS
xset s off
xset s noblank
xset -dpms

# Set cursor
xsetroot -cursor_name left_ptr 2>/dev/null || true
CURSOR_INIT_EOF

RUN chmod +x /home/doofus/init_cursor.sh && \
    chown doofus:doofus /home/doofus/init_cursor.sh

# Copy and set up screenshot script
COPY take_screenshot.sh /home/doofus/take_screenshot.sh
RUN chmod +x /home/doofus/take_screenshot.sh && \
    chown doofus:doofus /home/doofus/take_screenshot.sh

# Copy and set up screenfilm script
COPY take_screenfilm.sh /home/doofus/take_screenfilm.sh
RUN chmod +x /home/doofus/take_screenfilm.sh && \
    chown doofus:doofus /home/doofus/take_screenfilm.sh

# Create supervisord configuration
RUN cat > /etc/supervisor/conf.d/supervisord.conf << 'SUPERVISOR_EOF'
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=Xvfb :1 -screen 0 1024x768x16
autorestart=true
stdout_logfile=/var/log/supervisor/xvfb.log
stderr_logfile=/var/log/supervisor/xvfb.log
priority=100

[program:x11vnc]
command=x11vnc -display :1 -passwd doofus -listen localhost -xkb -ncache 10 -ncache_cr -forever -shared
autorestart=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc.log
priority=200

[program:xfce4]
command=/bin/bash -c 'export DISPLAY=:1 XCURSOR_THEME=DMZ-White XCURSOR_SIZE=48 && xfce4-session'
autorestart=true
stdout_logfile=/var/log/supervisor/xfce4.log
stderr_logfile=/var/log/supervisor/xfce4.log
user=doofus
environment=HOME="/home/doofus",USER="doofus",DISPLAY=":1",XCURSOR_THEME="DMZ-White",XCURSOR_SIZE="48"
priority=300

[program:novnc]
command=websockify --web=/usr/share/novnc/ 6080 localhost:5900
autorestart=true
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc.log
priority=400

[program:cursor_init]
command=/home/doofus/init_cursor.sh
autorestart=false
startsecs=0
startretries=3
stdout_logfile=/var/log/supervisor/cursor_init.log
stderr_logfile=/var/log/supervisor/cursor_init.log
user=doofus
environment=HOME="/home/doofus",USER="doofus",DISPLAY=":1",XCURSOR_THEME="DMZ-White",XCURSOR_SIZE="48"
priority=500

[program:ffmpeg_recording]
command=/home/doofus/start_recording.sh
autorestart=true
stdout_logfile=/var/log/supervisor/ffmpeg.log
stderr_logfile=/var/log/supervisor/ffmpeg.log
user=doofus
environment=HOME="/home/doofus",USER="doofus",DISPLAY=":1"
priority=600
SUPERVISOR_EOF

# Expose VNC and noVNC ports
EXPOSE 5901 6080

# Switch to doofus user
USER doofus
WORKDIR /home/doofus

# Add cursor environment to user's bash profile
RUN echo "export XCURSOR_THEME=DMZ-White" >> /home/doofus/.bashrc && \
    echo "export XCURSOR_SIZE=48" >> /home/doofus/.bashrc && \
    echo "export DISPLAY=:1" >> /home/doofus/.bashrc

# Start supervisor as root
USER root
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
