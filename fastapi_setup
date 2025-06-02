#!/bin/bash

# Customize your application port here
APP_PORT=8000

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

echo "enabling ${APP_PORT}/tcp for the application..."
sudo ufw allow ${APP_PORT}/tcp



echo "Enabling UFW..."
sudo ufw --force enable

echo "Starting UFW service..."
sudo systemctl start ufw

echo "Checking UFW status..."
sudo ufw status verbose


echo
echo "All done! Your server now uses UFW."
echo "Only SSH (22) and app port (${APP_PORT}) are open. Modify the script if you need to open more ports."

echo "starting the fastapi dev server on port ${APP_PORT}"

echo 

echo "Creating a virtual environment..."
python3 -m venv .venv

echo "Activating the virtual environment..."
source .venv/bin/activate

echo "Installing FastAPI and Uvicorn..."

python3 -m pip install fastapi[standard]

if [ -f "requirements.txt" ]; then
  echo "Installing dependencies from requirements.txt..."
  python3 -m pip install -r requirements.txt
else
  echo "No requirements.txt found, skipping dependency installation."
fi

echo "Starting the FastAPI development server on port ${APP_PORT}..."

fastapi dev main.py --host 0.0.0.0 --port ${APP_PORT}

