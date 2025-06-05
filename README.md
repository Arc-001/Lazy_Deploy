# Lazy Deploy

This project is a set of scripts designed for quick deployment of web applications and services. It includes scripts for setting up Docker, a FastAPI environment, MongoDB with Mongo Express, and Nginx with SSL.

**Disclaimer:** These scripts are intended for development and rapid prototyping purposes only. Security best practices have not been the primary focus during their creation. Use at your own risk and do not use for production environments without thorough review and hardening.

## Project Structure

```
.
├── docker_setup.sh
├── fastapi_setup.sh
├── mongo_docker_deploy.sh
├── nginx_setup.sh
└── README.md
```

- **`docker_setup.sh`**: Installs Docker and its dependencies on an Ubuntu system.
- **`fastapi_setup.sh`**: Sets up an environment for a FastAPI application. It installs Python, pip, venv, configures UFW (Uncomplicated Firewall), and starts a FastAPI development server.
- **`mongo_docker_deploy.sh`**: Deploys MongoDB and Mongo Express using Docker containers. It sets up a Docker network and configures the necessary environment variables for the containers.
- **`nginx_setup.sh`**: Installs and configures Nginx as a reverse proxy. It sets up UFW, installs Nginx, configures server blocks for subdomains, and automates SSL certificate acquisition and renewal using Certbot.

## General Prerequisites

1.  **Clone the repository (if applicable).**
2.  **Make scripts executable:** Before running any script, make it executable. For example:
    ```bash
    chmod +x docker_setup.sh
    chmod +x fastapi_setup.sh
    chmod +x mongo_docker_deploy.sh
    chmod +x nginx_setup.sh
    ```

## Script Details and Usage

### 1. Docker Setup (`docker_setup.sh`)

This script installs Docker Engine, CLI, containerd.io, and related plugins on an Ubuntu system.

**To run:**
```bash
./docker_setup.sh
```
It will:
*   Update package lists.
*   Install necessary dependencies for Docker.
*   Add Docker's official GPG key and repository.
*   Install Docker components.
*   Test the Docker installation by running the `hello-world` container.

### 2. FastAPI Environment Setup (`fastapi_setup.sh`)

This script prepares a server for running a FastAPI application.

**To run:**
```bash
./fastapi_setup.sh
```
Key actions:
*   Updates package lists.
*   Installs Python, pip, and venv.
*   Flushes existing iptables rules and sets default policies to ACCEPT.
*   Installs and configures UFW, allowing SSH (port 22) and the application port (default 8000).
*   Creates a Python virtual environment (`.venv`).
*   Installs FastAPI and Uvicorn.
*   Installs dependencies from `requirements.txt` if it exists.
*   Starts the FastAPI development server (`fastapi dev main.py`).

**Customization:**
*   The application port can be changed by modifying the `APP_PORT` variable at the beginning of the [`fastapi_setup.sh`](fastapi_setup.sh) file.
*   Ensure you have a `main.py` file for your FastAPI application in the same directory or modify the script to point to your application's entry point.

### 3. MongoDB and Mongo Express Docker Deployment (`mongo_docker_deploy.sh`)

This script deploys MongoDB and Mongo Express using Docker.

**Prerequisites:**
*   Docker must be installed (you can use [`docker_setup.sh`](docker_setup.sh)).
*   A `.env` file in the same directory with the following variables:
    ```env
    MONGO_PORT=27017
    ROOT_USERNAME=your_mongo_admin_user
    ROOT_PASS=your_mongo_admin_password
    ```

**To run:**
```bash
./mongo_docker_deploy.sh
```
It will:
*   Ensure Docker is set up (by calling [`docker_setup.sh`](docker_setup.sh)).
*   Create a Docker network named `db-network`.
*   Pull the latest `mongodb` and `mongo-express` images.
*   Load environment variables from the `.env` file.
*   Run MongoDB and Mongo Express containers in detached mode, connected to the `db-network`.
*   Prompt the user to open firewall ports for MongoDB (default 27017) and Mongo Express (8081) via UFW.

### 4. Nginx Setup with SSL (`nginx_setup.sh`)

This script installs Nginx, configures it as a reverse proxy for multiple subdomains, and sets up SSL using Certbot.

**Customization (at the top of the script):**
*   `app_port`: Default port Nginx listens on (typically 80 for HTTP, Certbot handles HTTPS).
*   `domain`: Your main domain name (e.g., "example.com").
*   `list_of_subdomains`: An array of subdomains you want to configure (e.g., `("www" "api" "blog")`).
*   `list_of_startup_scripts_location`: An array of paths to startup scripts for your backend applications. These will be added to crontab to run on reboot if confirmed by the user.

**To run:**
```bash
./nginx_setup.sh
```
It will:
*   Update package lists and install Python.
*   Flush iptables rules and configure UFW (allowing SSH, HTTP, HTTPS, and 'Nginx Full').
*   Install Nginx and start its service.
*   Optionally, add backend application startup scripts to crontab.
*   Prompt for the port number for each subdomain to set up reverse proxying.
*   Generate Nginx server block configurations for each subdomain.
*   Write the configuration to `/etc/nginx/sites-available/reverse_proxy.conf` and create a symbolic link in `/etc/nginx/sites-enabled/`.
*   Test the Nginx configuration and reload Nginx.
*   Install Certbot and the Nginx plugin for Certbot.
*   Run Certbot to obtain SSL certificates for the specified domain and subdomains.
*   Set up automatic renewal for SSL certificates.

**Important:**
*   Ensure your DNS records for the domain and subdomains are correctly pointing to your server's IP address before running the Certbot part of the script.
*   The script will prompt for confirmation before applying Nginx configurations and running Certbot commands.

## Contributing

Feel free to open issues or submit pull requests if you have suggestions or improvements.