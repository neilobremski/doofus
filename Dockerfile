FROM ubuntu:24.04

# Use Docker's built-in architecture arguments
ARG TARGETPLATFORM
ARG TARGETARCH

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
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
    firefox \
    dmz-cursor-theme \
    xcursor-themes \
    && rm -rf /var/lib/apt/lists/*

# Set cursor environment variables globally
ENV XCURSOR_THEME=DMZ-White
ENV XCURSOR_SIZE=48

# Create a non-root user
RUN useradd -m -s /bin/bash doofus && \
    echo "doofus:doofus" | chpasswd

# Set up VNC
RUN mkdir -p /home/doofus/.vnc && \
    echo "doofus" | vncpasswd -f > /home/doofus/.vnc/passwd && \
    chmod 600 /home/doofus/.vnc/passwd && \
    chown -R doofus:doofus /home/doofus/.vnc

# Create screenshots directory
RUN mkdir -p /home/doofus/screenshots && \
    chown -R doofus:doofus /home/doofus/screenshots

# Configure cursor theme for the doofus user
RUN mkdir -p /home/doofus/.icons/default && \
    echo "[Icon Theme]" > /home/doofus/.icons/default/index.theme && \
    echo "Inherits=DMZ-White" >> /home/doofus/.icons/default/index.theme && \
    chown -R doofus:doofus /home/doofus/.icons

# Create cursor initialization script
RUN cat > /home/doofus/init_cursor.sh << 'CURSOR_INIT_EOF'
#!/bin/bash
export DISPLAY=:1
export XCURSOR_THEME=DMZ-White
export XCURSOR_SIZE=48
xsetroot -cursor_name left_ptr 2>/dev/null || true
CURSOR_INIT_EOF

RUN chmod +x /home/doofus/init_cursor.sh && \
    chown doofus:doofus /home/doofus/init_cursor.sh

# Update supervisord configuration to include cursor initialization
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create an enhanced supervisord configuration
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

[program:x11vnc]
command=x11vnc -display :1 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever -shared
autorestart=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc.log

[program:xfce4]
command=/bin/bash -c 'export DISPLAY=:1 XCURSOR_THEME=DMZ-White XCURSOR_SIZE=48 && xfce4-session'
autorestart=true
stdout_logfile=/var/log/supervisor/xfce4.log
stderr_logfile=/var/log/supervisor/xfce4.log
user=doofus
environment=HOME="/home/doofus",USER="doofus",DISPLAY=":1",XCURSOR_THEME="DMZ-White",XCURSOR_SIZE="48"

[program:novnc]
command=websockify --web=/usr/share/novnc/ 6080 localhost:5900
autorestart=true
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc.log

[program:cursor_init]
command=/home/doofus/init_cursor.sh
autorestart=false
startsecs=0
startretries=1
stdout_logfile=/var/log/supervisor/cursor_init.log
stderr_logfile=/var/log/supervisor/cursor_init.log
user=doofus
environment=HOME="/home/doofus",USER="doofus",DISPLAY=":1",XCURSOR_THEME="DMZ-White",XCURSOR_SIZE="48"
priority=999
SUPERVISOR_EOF

# Set up the display
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080

# Expose VNC and noVNC ports
EXPOSE 5901 6080

# Switch to doofus user
USER doofus
WORKDIR /home/doofus

# Create startup script with cursor initialization
COPY --chown=doofus:doofus start.sh /home/doofus/start.sh
RUN chmod +x /home/doofus/start.sh

# Add cursor environment to user's bash profile
RUN echo "export XCURSOR_THEME=DMZ-White" >> /home/doofus/.bashrc && \
    echo "export XCURSOR_SIZE=48" >> /home/doofus/.bashrc && \
    echo "export DISPLAY=:1" >> /home/doofus/.bashrc

# Start supervisor
USER root
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
