#!/bin/bash
app_port=80
domain="example.com"
list_of_subdomains=("www" "api" "blog")
list_of_startup_scripts_location=("$HOME/git_repos/fastapi_app/startup.sh" "$HOME/git_repos/npm_app/startup2.sh")


echo "Updateing package lists for candidate packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "Installing python and pip3..."
sudo apt-get install -y python3 python3-pip

echo "installing python3-venv..."
sudo apt-get install -y python3-venv


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

echo "Installing UFW if not present..."
sudo apt-get install -y ufw

echo "Allowing SSH (port 22)..."
sudo ufw allow 22/tcp

echo "enabling ${app_port}/tcp for the application..."
sudo ufw allow ${app_port}/tcp

echo "Enabling NGINX full"
sudo ufw allow 'Nginx Full'
sudo ufw allow 443/tcp


echo "Enabling UFW..."
sudo ufw --force enable

echo "Starting UFW service..."
sudo systemctl start ufw

echo "Checking UFW status..."
sudo ufw status verbose


echo
echo "All done! Your server now uses UFW."


#installing nginx
echo "Installing Nginx..."
sudo apt install nginx -y

#starting nginx
echo "Starting Nginx service..."
sudo systemctl enable nginx
sudo systemctl start nginx

#insert commands for the backend
echo "Have you added the startup commands for your applications? (y/n): "
read ADD_STARTUP_CMDS
if [[ "$ADD_STARTUP_CMDS" =~ ^[Yy]$ ]]; then
  echo "Adding startup commands for applications..."
  for script in "${list_of_startup_scripts_location[@]}"; do
    if [[ -f "$script" ]]; then
      echo "Adding startup script: $script"
      sudo chmod +x "$script"
      echo "@reboot $script" | crontab -
    else
      echo "Script not found: $script"
    fi
  done
else
  echo "Skipping adding startup commands."
fi


#gettind details of reverse proxy

echo "setting up reverse proxy for each subdomain..."

declare -A subdomain_port_map=()

for subdomain in "${list_of_subdomains[@]}"; do
    read -p "Enter the port for $subdomain.$domain: " subdomain_port
    subdomain_port_map["$subdomain"]="$subdomain_port"
done

total_config=""

for subdomain in "${!subdomain_port_map[@]}"; do
    port="${subdomain_port_map[$subdomain]}"
    total_config+="server {
        listen 80;
        server_name $subdomain.$domain;

        location / {
            proxy_pass http://localhost:$port;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }\n\n"
done

echo "making a link of this new config as given below please confirm"
echo -e "$total_config"

read -p "Do you want to proceed with this configuration? (y/n): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Creating Nginx configuration file..."
    sudo bash -c "echo -e \"$total_config\" > /etc/nginx/sites-available/reverse_proxy.conf"
    echo "Linking the configuration file to sites-enabled..."
    sudo ln -sf /etc/nginx/sites-available/reverse_proxy.conf /etc/nginx/sites-enabled/
    
    echo "Testing Nginx configuration..."
    sudo nginx -t
    
    if [ $? -eq 0 ]; then
        echo "Nginx configuration is valid. Reloading Nginx..."
        sudo systemctl reload nginx
        echo "Nginx reloaded successfully."
    else
        echo "Nginx configuration is invalid. Please check the configuration file."
    fi
else
    echo "Configuration not applied."
fi

echo "Config have been applied successfully"
sudo systemctl enable nginx

echo "Now setting up SSL using certbot..."

echo "Installing dependencies for certbot..."

sudo apt install certbot python3-certbot-nginx -y

domain_string=""
for subdomain in "${list_of_subdomains[@]}"; do
    domain_string+="-d $subdomain.$domain "
done
domain_string+="-d $domain"
command_string="sudo certbot --nginx $domain_string"
echo "Running command: $command_string"
read -p "Do you want to proceed with this command? (y/n): " confirm_certbot

if [[ "$confirm_certbot" =~ ^[Yy]$ ]]; then
    echo "Running certbot command..."
    eval $command_string
else
    echo "Certbot command not executed."
fi

echo "setting up automatic renewal for SSL certificates..."

sudo certbot renew --dry-run

echo "Nginx setup completed successfully!"
echo "Your server is now configured with Nginx, UFW, and SSL."
echo "You can access your applications at the following URLs:"
for subdomain in "${list_of_subdomains[@]}"; do
    echo "https://$subdomain.$domain"
done
echo "https://$domain"
echo "Please ensure your DNS records are correctly set up for the subdomains."
echo "--------------EOF------------"





  