#!/bin/bash

#################################################################
# VNC + XFCE + HTTP Auth Complete Setup Script for OCI Ubuntu
# Date: 2025-10-02
# User: Arc-001
#################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║   VNC + XFCE + HTTP Proxy Complete Setup Script           ║
║   For OCI Ubuntu with Authentication                       ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}❌ Please do not run as root. Run as your regular user.${NC}"
    exit 1
fi

CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$CURRENT_USER)
DISPLAY_NUM=1
VNC_PORT=5901
WS_PORT=6080
HTTP_PORT=80

echo -e "${GREEN}✓ Running as user: $CURRENT_USER${NC}"
echo -e "${GREEN}✓ Home directory: $USER_HOME${NC}"
echo ""

#################################################################
# STEP 1: Update System and Install All Dependencies
#################################################################
echo -e "${BLUE}[1/9] Updating system and installing all required packages...${NC}"

sudo apt update
sudo apt upgrade -y

# Install all required packages in one go
sudo apt install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    nginx \
    apache2-utils \
    novnc \
    websockify \
    dbus-x11 \
    xorg \
    xfonts-base \
    python3-numpy \
    net-tools \
    curl

echo -e "${GREEN}✓ All packages installed successfully${NC}"

#################################################################
# STEP 2: Stop Any Existing VNC Services
#################################################################
echo -e "${BLUE}[2/9] Cleaning up any existing VNC services...${NC}"

# Kill any existing VNC servers
vncserver -kill :* 2>/dev/null || true
pkill -9 Xtigervnc 2>/dev/null || true

# Stop and disable any existing systemd services
sudo systemctl stop vncserver@*.service 2>/dev/null || true
sudo systemctl disable vncserver@*.service 2>/dev/null || true
sudo systemctl stop websockify.service 2>/dev/null || true
sudo systemctl disable websockify.service 2>/dev/null || true

# Clean old VNC files
rm -rf $USER_HOME/.vnc/*.log 2>/dev/null || true
rm -rf $USER_HOME/.vnc/*.pid 2>/dev/null || true

echo -e "${GREEN}✓ Cleanup completed${NC}"

#################################################################
# STEP 3: Configure VNC Server
#################################################################
echo -e "${BLUE}[3/9] Configuring VNC server...${NC}"

# Create VNC directory
mkdir -p $USER_HOME/.vnc

# Set VNC password
if [ ! -f "$USER_HOME/.vnc/passwd" ]; then
    echo -e "${YELLOW}Please set a VNC password (6-8 characters recommended):${NC}"
    vncpasswd
else
    echo -e "${YELLOW}⚠ VNC password already exists${NC}"
    read -p "Do you want to reset the VNC password? (y/N): " reset_pwd
    if [[ $reset_pwd =~ ^[Yy]$ ]]; then
        vncpasswd
    fi
fi

# Create xstartup file with D-Bus 
cat > $USER_HOME/.vnc/xstartup << 'XSTARTUP_EOF'
#!/bin/bash

# Ensure D-Bus is available
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    if [ -f /usr/bin/dbus-launch ]; then
        eval $(dbus-launch --sh-syntax --exit-with-session)
    fi
fi

# Unset problematic session variables
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Set environment variables
export XKL_XMODMAP_DISABLE=1
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Start D-Bus if not running
if ! pgrep -x "dbus-daemon" > /dev/null; then
    eval $(dbus-launch --sh-syntax)
fi

# Start XFCE Desktop
exec startxfce4
XSTARTUP_EOF

chmod +x $USER_HOME/.vnc/xstartup

# Create VNC config file
cat > $USER_HOME/.vnc/config << 'CONFIG_EOF'
# VNC Configuration
geometry=1920x1080
dpi=96
localhost
alwaysshared
depth=24
CONFIG_EOF

echo -e "${GREEN}✓ VNC configuration files created${NC}"

#################################################################
# STEP 4: Create VNC Systemd Service
#################################################################
echo -e "${BLUE}[4/9] Creating VNC systemd service...${NC}"

sudo tee /etc/systemd/system/vncserver@.service > /dev/null << SYSTEMD_EOF
[Unit]
Description=Remote Desktop VNC Service (Display :%i)
After=syslog.target network.target

[Service]
Type=forking
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$USER_HOME

# Environment variables
Environment="HOME=$USER_HOME"
Environment="USER=$CURRENT_USER"
Environment="PATH=/usr/bin:/usr/local/bin"
Environment="XDG_RUNTIME_DIR=/run/user/%U"

# VNC server commands
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -localhost -rfbauth $USER_HOME/.vnc/passwd -depth 24
ExecStop=/usr/bin/vncserver -kill :%i

# Process management
PIDFile=$USER_HOME/.vnc/%H:%i.pid
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@${DISPLAY_NUM}.service

echo -e "${GREEN}✓ VNC systemd service created${NC}"

#################################################################
# STEP 5: Start VNC Server
#################################################################
echo -e "${BLUE}[5/9] Starting VNC server...${NC}"

# Start VNC manually first to initialize
vncserver :${DISPLAY_NUM} -geometry 1920x1080 -localhost -depth 24

sleep 5

# Check if VNC started successfully
if pgrep -u $CURRENT_USER Xtigervnc > /dev/null; then
    echo -e "${GREEN}✓ VNC server started successfully on display :${DISPLAY_NUM}${NC}"
    
    # Restart as systemd service
    vncserver -kill :${DISPLAY_NUM} || true
    sleep 2
    sudo systemctl start vncserver@${DISPLAY_NUM}.service
    sleep 3
    
    if sudo systemctl is-active --quiet vncserver@${DISPLAY_NUM}.service; then
        echo -e "${GREEN}✓ VNC systemd service is running${NC}"
    else
        echo -e "${YELLOW}⚠ VNC systemd service may have issues, but manual start succeeded${NC}"
    fi
else
    echo -e "${RED}✗ VNC server failed to start${NC}"
    echo -e "${YELLOW}Checking VNC log:${NC}"
    cat $USER_HOME/.vnc/*:${DISPLAY_NUM}.log 2>/dev/null | tail -20
    exit 1
fi

#################################################################
# STEP 6: Setup noVNC and Websockify
#################################################################
echo -e "${BLUE}[6/9] Setting up noVNC and websockify...${NC}"

# Create websockify systemd service
sudo tee /etc/systemd/system/websockify.service > /dev/null << WEBSOCK_EOF
[Unit]
Description=Websockify Service for noVNC
After=network.target vncserver@${DISPLAY_NUM}.service
Requires=vncserver@${DISPLAY_NUM}.service

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$USER_HOME

ExecStart=/usr/bin/websockify --web=/usr/share/novnc ${WS_PORT} localhost:${VNC_PORT}

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
WEBSOCK_EOF

sudo systemctl daemon-reload
sudo systemctl enable websockify.service
sudo systemctl start websockify.service

sleep 3

if sudo systemctl is-active --quiet websockify.service; then
    echo -e "${GREEN}✓ Websockify service started successfully${NC}"
else
    echo -e "${RED}✗ Websockify service failed to start${NC}"
    sudo journalctl -u websockify.service -n 20 --no-pager
fi

#################################################################
# STEP 7: Configure Nginx with HTTP Authentication
#################################################################
echo -e "${BLUE}[7/9] Configuring nginx reverse proxy with authentication...${NC}"

# Setup HTTP authentication
if [ ! -f "/etc/nginx/.htpasswd" ]; then
    echo -e "${YELLOW}Create HTTP authentication credentials:${NC}"
    read -p "Enter username for HTTP access [default: admin]: " HTTP_USER
    HTTP_USER=${HTTP_USER:-admin}
    sudo htpasswd -c /etc/nginx/.htpasswd "$HTTP_USER"
else
    echo -e "${YELLOW}⚠ HTTP auth file already exists${NC}"
    read -p "Do you want to add another user? (y/N): " add_user
    if [[ $add_user =~ ^[Yy]$ ]]; then
        read -p "Enter username: " HTTP_USER
        sudo htpasswd /etc/nginx/.htpasswd "$HTTP_USER"
    fi
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

# Create nginx configuration
sudo tee /etc/nginx/sites-available/vnc > /dev/null << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Increase buffer sizes for VNC
    client_max_body_size 100M;
    proxy_buffering off;

    # HTTP Basic Authentication
    auth_basic "VNC Access - Authentication Required";
    auth_basic_user_file /etc/nginx/.htpasswd;

    # Main noVNC interface
    location / {
        proxy_pass http://localhost:6080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeout settings
        proxy_read_timeout 61s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
    }

    # WebSocket endpoint
    location /websockify {
        proxy_pass http://localhost:6080/websockify;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        proxy_read_timeout 61s;
        proxy_connect_timeout 60s;
    }

    # Error pages
    error_page 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
NGINX_EOF

# Remove default nginx site and enable VNC site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/vnc /etc/nginx/sites-enabled/

# Test nginx configuration
echo -e "${YELLOW}Testing nginx configuration...${NC}"
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
    sudo systemctl restart nginx
    
    if sudo systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx restarted successfully${NC}"
    else
        echo -e "${RED}✗ Nginx failed to restart${NC}"
        sudo systemctl status nginx --no-pager
    fi
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    sudo nginx -t
    exit 1
fi

#################################################################
# STEP 8: Configure Firewall (ufw)
#################################################################

# Flushing ip tables

echo "Flushing all iptables rules..."
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -t raw -F
sudo iptables -t raw -X
sudo iptables -t security -F
sudo iptables -t security -X


# Making all permitted
echo "Setting iptables default policies to ACCEPT..."

sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# If iptables-persistent is installed, save the empty rules
if dpkg -l | grep -qw iptables-persistent; then
  echo "Saving empty iptables rules with iptables-persistent..."
  sudo netfilter-persistent save
fi

# Remove iptables-persistent if you want
read -p "Do you want to remove iptables-persistent? (y/n): " REMOVE_IPTP
if [[ "$REMOVE_IPTP" =~ ^[Yy]$ ]]; then
  echo "Removing iptables-persistent..."
  sudo apt-get remove --purge -y iptables-persistent
fi

#installing ufw

echo "Installing UFW if not present..."
sudo apt-get install -y ufw

# Port 22 for SSH
echo "Allowing SSH (port 22)..."
sudo ufw allow 22/tcp

#port 80 for HTTP
echo "Allowing HTTP (port 80)..."
echo "enabling 80/tcp for the application..."
sudo ufw allow 80/tcp
sudo ufw allow 80/udp


echo "Enabling UFW..."
sudo ufw --force enable

echo "Starting UFW service..."
sudo systemctl enable ufw
sudo systemctl start ufw

echo "Checking UFW status..."
sudo ufw status verbose


echo
echo "All done! Your server now uses UFW."
echo "Only SSH (22) and HTTP (80) are open. Modify the script if you need to open more ports."

echo "starting the fastapi dev server on port ${APP_PORT}"


#################################################################
# STEP 9: Final Status Check and Information
#################################################################
echo -e "${BLUE}[9/9] Running final status checks...${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              SETUP COMPLETED SUCCESSFULLY!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Service Status
echo -e "${BLUE}═══ Services Status ═══${NC}"
printf "%-20s " "VNC Server:"
if sudo systemctl is-active --quiet vncserver@${DISPLAY_NUM}.service; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Stopped${NC}"
fi

printf "%-20s " "Websockify:"
if sudo systemctl is-active --quiet websockify.service; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Stopped${NC}"
fi

printf "%-20s " "Nginx:"
if sudo systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Stopped${NC}"
fi
echo ""

# Connection Information
echo -e "${BLUE}═══ VNC Server Information ═══${NC}"
echo "  Display:      :${DISPLAY_NUM}"
echo "  VNC Port:     ${VNC_PORT} (localhost only)"
echo "  WebSocket:    ${WS_PORT} (localhost only)"
echo "  HTTP Port:    ${HTTP_PORT}"
echo "  Resolution:   1920x1080"
echo "  User:         $CURRENT_USER"
echo ""

# Access Methods
echo -e "${BLUE}═══ Access Methods ═══${NC}"
echo ""
echo -e "${GREEN}1. Web Browser Access (Recommended):${NC}"
echo "   URL: http://${SERVER_IP}"
echo "   Login with your HTTP authentication credentials"
echo ""
echo -e "${GREEN}2. VNC Client Access (via SSH Tunnel):${NC}"
echo "   Step 1: Create SSH tunnel"
echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} ${CURRENT_USER}@${SERVER_IP}"
echo ""
echo "   Step 2: Connect VNC client to"
echo "   localhost:${DISPLAY_NUM} or localhost:${VNC_PORT}"
echo ""

# Important Notes
echo -e "${YELLOW}═══ IMPORTANT NOTES ═══${NC}"
echo ""
echo -e "${YELLOW}OCI Security List Configuration Required!${NC}"
echo "   1. Go to OCI Console"
echo "   2. Navigate to: Networking → Virtual Cloud Networks"
echo "   3. Select your VCN → Security Lists"
echo "   4. Add Ingress Rule:"
echo "      - Source CIDR: 0.0.0.0/0 (or restrict to your IP)"
echo "      - IP Protocol: TCP"
echo "      - Destination Port: ${HTTP_PORT}"
echo ""

# Useful Commands
echo -e "${BLUE}═══ Useful Commands ═══${NC}"
echo ""
echo "View VNC logs:"
echo "  tail -f $USER_HOME/.vnc/*:${DISPLAY_NUM}.log"
echo ""
echo "Restart VNC:"
echo "  sudo systemctl restart vncserver@${DISPLAY_NUM}.service"
echo ""
echo "Check VNC status:"
echo "  sudo systemctl status vncserver@${DISPLAY_NUM}.service"
echo ""
echo "Manual VNC control:"
echo "  vncserver :${DISPLAY_NUM}        # Start"
echo "  vncserver -kill :${DISPLAY_NUM}  # Stop"
echo ""
echo "View all service logs:"
echo "  sudo journalctl -u vncserver@${DISPLAY_NUM}.service -f"
echo "  sudo journalctl -u websockify.service -f"
echo "  sudo journalctl -u nginx.service -f"
echo ""
echo "Add more HTTP users:"
echo "  sudo htpasswd /etc/nginx/.htpasswd username"
echo ""


echo -e "${GREEN}Setup script completed!${NC}"
echo ""
