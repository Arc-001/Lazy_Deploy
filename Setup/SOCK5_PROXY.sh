#!/bin/bash

# ==========================================
# CONFIGURATION VARIABLES
# ==========================================
DOMAIN="domain.example.com"
PASSWORD="YOUR_STRONG_PASSWORD_HERE"
EMAIL="your-email@example.com"
DNS_SERVERS="1.1.1.1 1.0.0.1"
# ==========================================

# Exit immediately if a command exits with a non-zero status
set -e

echo "[1/10] Securing and Flushing IPTables..."
# Set default policies to ACCEPT to prevent lockout during flush
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t nat -P OUTPUT ACCEPT

# Flush all rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Purge conflicting persistent firewall packages
apt-get purge -y iptables-persistent netfilter-persistent
rm -rf /etc/iptables

echo "[2/10] Updating System and Installing Dependencies..."
apt-get update
apt-get install -y socat curl wget python3-certbot-nginx nginx trojan ufw

echo "[3/10] Configuring System DNS (Privacy Fix)..."
# Force system to use Cloudflare DNS instead of Oracle default
sed -i 's/#DNS=/DNS=/g' /etc/systemd/resolved.conf
sed -i "s/^DNS=.*/DNS=$DNS_SERVERS/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved

echo "[4/10] Configuring UFW Firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "[5/10] Obtaining SSL Certificates..."
# Stop Nginx to release port 80 for standalone verification
systemctl stop nginx
certbot certonly --standalone --preferred-challenges http \
  -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  echo "CRITICAL ERROR: SSL Certificate generation failed. Check your DNS settings."
  exit 1
fi

echo "[6/10] Configuring Nginx (Fallback Server)..."
# Configure Nginx to listen ONLY on localhost port 80
cat >/etc/nginx/sites-available/default <<EOF
server {
    listen 127.0.0.1:80 default_server;
    server_name $DOMAIN;

    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}
EOF

# Clean up symlinks
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

echo "[7/10] Configuring Trojan..."
cat >/etc/trojan/config.json <<EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$PASSWORD"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem",
        "key": "/etc/letsencrypt/live/$DOMAIN/privkey.pem",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF

echo "[8/10] Patching Trojan Service Permissions..."
# Locate the service file and force it to run as root to read certs
SERVICE_FILE=$(systemctl show -p FragmentPath trojan.service | cut -d= -f2)
if [ -z "$SERVICE_FILE" ]; then SERVICE_FILE="/lib/systemd/system/trojan.service"; fi

sed -i 's/User=nobody/User=root/g' "$SERVICE_FILE"
sed -i 's/User=trojan/User=root/g' "$SERVICE_FILE"
sed -i 's/^Group=/#Group=/g' "$SERVICE_FILE"

echo "[9/10] Setting up Auto-Renewal Hooks..."
mkdir -p /etc/letsencrypt/renewal-hooks/post
echo '#!/bin/bash
systemctl restart trojan' >/etc/letsencrypt/renewal-hooks/post/trojan-restart.sh
chmod +x /etc/letsencrypt/renewal-hooks/post/trojan-restart.sh

echo "[10/10] Starting Services..."
systemctl daemon-reload
systemctl enable nginx trojan
systemctl restart nginx
systemctl restart trojan

# Final Verification
TROJAN_STATUS=$(systemctl is-active trojan)
NGINX_STATUS=$(systemctl is-active nginx)

if [ "$TROJAN_STATUS" != "active" ] || [ "$NGINX_STATUS" != "active" ]; then
  echo "ERROR: Services failed to start."
  echo "Trojan: $TROJAN_STATUS"
  echo "Nginx: $NGINX_STATUS"
  exit 1
fi

echo ""
echo "############################################################"
echo "INSTALLATION COMPLETE"
echo "############################################################"
echo ""
echo "Trojan URL (Copy to Client):"
echo "trojan://$PASSWORD@$DOMAIN:443?sni=$DOMAIN#MyServer"
echo ""
