# lazy deploy

This project is a FastAPI application designed for quick deployment. It includes scripts for setting up the environment and managing firewall rules.

## Project Structure

```
.
├── .gitignore
├── docker_setup.sh
├── main.py
├── setup.sh
└── README.md
```

- **`main.py`**: The main FastAPI application code.
- **`setup.sh`**: A script to set up the server environment, install dependencies, configure UFW (Uncomplicated Firewall), and run the FastAPI application.
- **`docker_setup.sh`**: A script to install Docker on an Ubuntu system.
- **`.gitignore`**: Specifies intentionally untracked files that Git should ignore.

## Setup and Running the Application

1.  **Clone the repository (if applicable).**
2.  **Make the setup script executable:**
    ```bash
    chmod +x setup.sh
    ```
3.  **Run the setup script:**
    ```bash
    ./setup.sh
    ```
    This script will:
    *   Update package lists.
    *   Install Python, pip, and venv.
    *   Flush existing iptables rules and set default policies to ACCEPT.
    *   Optionally remove `iptables-persistent`.
    *   Install and configure UFW, allowing SSH (port 22) and the application port (default 8000).
    *   Create a Python virtual environment in `.venv`.
    *   Activate the virtual environment.
    *   Install FastAPI and Uvicorn.
    *   Install dependencies from `requirements.txt` if it exists.
    *   Start the FastAPI development server using `fastapi dev main.py` on `0.0.0.0` at the specified application port (default 8000).

    You can customize the application port by modifying the `APP_PORT` variable at the beginning of the [`setup.sh`](setup.sh) file.

## Docker Setup

If you intend to use Docker, you can set it up using the `docker_setup.sh` script.

1.  **Make the Docker setup script executable:**
    ```bash
    chmod +x docker_setup.sh
    ```
2.  **Run the Docker setup script:**
    ```bash
    ./docker_setup.sh
    ```
    This script will:
    *   Update package lists.
    *   Install necessary dependencies for Docker.
    *   Add Docker's official GPG key.
    *   Set up the Docker repository.
    *   Install Docker Engine, CLI, containerd.io, and related plugins.
    *   Test the Docker installation by running the `hello-world` container.


## Contributing

Feel free to open issues or submit pull requests.
