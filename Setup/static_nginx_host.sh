#!/bin/bash

read -p "Enter your domain (e.g. xxx.yyy.zzz): " domain
read -p "Enter the path to your static HTML folder (e.g. /home/ubuntu/mysite): " static_path

echo "Updating package lists..."
sudo apt-get update -y
sudo apt-get upgrade -y

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

echo "Setting iptables default policies to ACCEPT..."
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

if dpkg -l | grep -qw iptables-persistent; then
  echo "Saving empty iptables rules with iptables-persistent..."
  sudo netfilter-persistent save
fi

read -p "Do you want to remove iptables-persistent? (y/n): " REMOVE_IPTP
if [[ "$REMOVE_IPTP" =~ ^[Yy]$ ]]; then
  sudo apt-get remove --purge -y iptables-persistent
fi

echo "Installing UFW..."
sudo apt-get install -y ufw

sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
sudo systemctl start ufw

echo "UFW status:"
sudo ufw status verbose

echo "Installing Nginx..."
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx

web_root="/var/www/$domain"
echo "Creating web root at $web_root..."
sudo mkdir -p "$web_root"

if [[ -d "$static_path" ]]; then
  echo "Copying static files from $static_path to $web_root..."
  sudo cp -r "$static_path"/. "$web_root/"
else
  echo "Warning: path '$static_path' not found. Placing a placeholder index.html..."
  echo "<h1>$domain is live</h1>" | sudo tee "$web_root/index.html" > /dev/null
fi

sudo chown -R www-data:www-data "$web_root"
sudo chmod -R 755 "$web_root"

config=$(cat <<EOF
server {
    listen 80;
    server_name $domain;

    root $web_root;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
)

echo
echo "Nginx config to be written:"
echo "────────────────────────────"
printf "%s\n" "$config"
echo "────────────────────────────"
read -p "Proceed? (y/n): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
  printf "%s" "$config" | sudo tee /etc/nginx/sites-available/"$domain".conf > /dev/null
  sudo ln -sf /etc/nginx/sites-available/"$domain".conf /etc/nginx/sites-enabled/

  # Remove default site if present
  sudo rm -f /etc/nginx/sites-enabled/default

  sudo nginx -t && sudo systemctl reload nginx
  echo "Nginx reloaded."
else
  echo "Nginx config not applied."
  exit 1
fi

echo
read -p "Set up SSL with Certbot? (y/n): " setup_ssl

if [[ "$setup_ssl" =~ ^[Yy]$ ]]; then
  sudo apt install certbot python3-certbot-nginx -y
  echo "Running: sudo certbot --nginx -d $domain"
  read -p "Proceed? (y/n): " confirm_certbot
  if [[ "$confirm_certbot" =~ ^[Yy]$ ]]; then
    sudo certbot --nginx -d "$domain"
    sudo certbot renew --dry-run
  else
    echo "Certbot skipped."
  fi
fi

echo
echo "Done! Your static site should be live at:"
[[ "$setup_ssl" =~ ^[Yy]$ ]] && echo "  https://$domain" || echo "  http://$domain"
echo "Web root: $web_root"
