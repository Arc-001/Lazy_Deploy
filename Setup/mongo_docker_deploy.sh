#!/bin/bash

echo "Setting up sudo docker"
chmod +x docker_setup.sh
./docker_setup.sh
sudo docker network create db-network
sudo docker pull mongodb
sudo docker pull mongo-express:latest
source .env


# Load environment variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Check if required environment variables are set
if [ -z "$MONGO_PORT" ] || [ -z "$ROOT_USERNAME" ] || [ -z "$ROOT_PASS" ]; then
  echo "Required environment variables are not set in .env file!"
  exit 1
fi


# Running the mongo container in
# detached mode wrt the given port, username and password
echo "Running MongoDB container..."
sudo docker run -d \
  --name mongo \
  --network db-network \
  -p 27017:${MONGO_PORT} \
  -e MONGO_INITDB_ROOT_USERNAME=${ROOT_USERNAME} \
    -e MONGO_INITDB_ROOT_PASSWORD=${ROOT_PASS} \
  mongo:latest

echo "Successfully started MongoDB container"


echo "Running Mongo Express container..."

sudo docker run -d \
  --name mongo-express \
  --network db-network \
  -p 8081:8081 \
  -e ME_CONFIG_MONGODB_SERVER=mongo \
  -e ME_CONFIG_MONGODB_PORT=${MONGO_PORT} \
  -e ME_CONFIG_MONGODB_ADMINUSERNAME=${ROOT_USERNAME} \
  -e ME_CONFIG_MONGODB_ADMINPASSWORD=${ROOT_PASS} \
  -e ME_CONFIG_BASICAUTH_USERNAME=${ROOT_USERNAME} \
  -e ME_CONFIG_BASICAUTH_PASSWORD=${ROOT_PASS} \
  
  mongo-express:latest

echo "Successfully started Mongo Express container"
echo "Do you wish to open the port for Mongodb? (y/n)"
read -r open_port
if [[ "$open_port" == "y" || "$open_port" == "Y" ]]; then
  echo "Opening port ${MONGO_PORT} for MongoDB..."
  sudo ufw allow ${MONGO_PORT}/tcp
  echo "Port ${MONGO_PORT} is now open."
else
  echo "Port ${MONGO_PORT} remains closed."
fi

echo
echo
echo "Do you wish to open the port for Mongo Express? (y/n)"
read -r open_port_express
if [[ "$open_port_express" == "y" || "$open_port_express" == "Y" ]]; then
  echo "Opening port 8081 for Mongo Express..."
  sudo ufw allow 8081/tcp
  echo "Port 8081 is now open."
else
  echo "Port 8081 remains closed."
fi

echo
echo "MongoDB and Mongo Express setup completed successfully!"

echo "INFO: \n MongoDB is running on port ${MONGO_PORT} \n Mongo Express is running on port 8081"



