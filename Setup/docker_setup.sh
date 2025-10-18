echo "Updateing for candidate packages..."

sudo apt-get update -y

echo "Installing dependencies..."

sudo apt-get install ca-certificates curl -y

sudo install -m 0755 -d /etc/apt/keyrings

echo "Adding Docker's official GPG key..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "Adding repo list of docker..."

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


echo "Updating package lists again..."

sudo apt-get update -y

echo "Installing Docker Engine, CLI, and containerd.io..."

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "esting docker installation..."

output=$(sudo docker run hello-world)
if [[ $? -eq 0 ]]; then
    echo
    echo
    echo "Docker is installed and working correctly."
else
    echo "Docker installation failed. Please check the output:"
    echo "$output"
    exit 1
fi
