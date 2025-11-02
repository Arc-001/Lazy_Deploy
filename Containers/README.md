# VS Code Containerization Project

A complete Docker-based development environment with VS Code (code-server) and supporting services.

## 📋 Features

- **Code-Server**: Browser-based VS Code IDE
- **PostgreSQL**: Relational database for development
- **Redis**: In-memory caching and sessions
- **MongoDB**: NoSQL database
- **Nginx**: Reverse proxy with SSL support
- **Portainer**: Container management UI
- **Docker-in-Docker**: Build and run containers from within VS Code

## 🏗️ Architecture

```
┌─────────────┐
│   Nginx     │ :80, :443 (Reverse Proxy)
└──────┬──────┘
       │
┌──────▼──────┐
│ Code-Server │ :8080 (VS Code in Browser)
└─────────────┘
       │
       ├──────┬──────────┬──────────┬────────────┐
       │      │          │          │            │
    ┌──▼──┐ ┌▼───┐  ┌───▼────┐ ┌───▼──────┐ ┌──▼───────┐
    │ PG  │ │Redis│ │MongoDB │ │Portainer │ │  Docker  │
    └─────┘ └─────┘ └────────┘ └──────────┘ └──────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ RAM recommended

### Installation

1. **Clone/Create project directory**
```bash
mkdir vscode-container-project
cd vscode-container-project
```

2. **Create directory structure**
```bash
mkdir -p config projects nginx/ssl
```

3. **Copy configuration files**
   - Place `docker-compose.yml` in root
   - Place `.env` in root
   - Place `nginx.conf` in `nginx/` directory

4. **Configure environment variables**
```bash
# Edit .env file
nano .env

# Set secure passwords
CODE_SERVER_PASSWORD=your_secure_password
SUDO_PASSWORD=your_sudo_password
POSTGRES_PASSWORD=your_db_password
```

5. **Start services**
```bash
# Start all services
docker-compose up -d

# Start only code-server
docker-compose up -d code-server

# View logs
docker-compose logs -f code-server
```

## 🌐 Access Points

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| VS Code | http://localhost:8080 | Password from `.env` |
| Nginx | http://localhost:80 | N/A |
| Portainer | http://localhost:9000 | Set on first login |
| PostgreSQL | localhost:5432 | devuser/devpass |
| MongoDB | localhost:27017 | admin/adminpass |
| Redis | localhost:6379 | No password |

## 📁 Directory Structure

```
vscode-container-project/
├── docker-compose.yml       # Main compose file
├── .env                     # Environment variables
├── config/                  # VS Code settings & extensions
├── projects/                # Your source code
├── nginx/
│   ├── nginx.conf          # Nginx configuration
│   └── ssl/                # SSL certificates
└── README.md
```

## 🛠️ Usage

### Installing VS Code Extensions

Extensions are installed in the browser UI or via CLI:

```bash
# Access container shell
docker exec -it vscode-container bash

# Install extension
code-server --install-extension ms-python.python
```

### Using Docker Inside Container

The compose file mounts the Docker socket, enabling Docker-in-Docker:

```bash
# Inside VS Code terminal
docker ps
docker build -t myapp .
docker run myapp
```

### Database Connections

**PostgreSQL:**
```
Host: postgres
Port: 5432
Database: devdb
User: devuser
Password: devpass
```

**MongoDB:**
```
Connection String: mongodb://admin:adminpass@mongodb:27017
```

**Redis:**
```
Host: redis
Port: 6379
```

## 🔧 Customization

### Adding More Services

Edit `docker-compose.yml`:

```yaml
  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
    ports:
      - "3306:3306"
    networks:
      - dev-network
```

### Changing Ports

Edit port mappings in `docker-compose.yml`:

```yaml
ports:
  - "8888:8080"  # Access on port 8888
```

### Resource Limits

Add resource constraints:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

## 🔒 Security

### Enable SSL

1. Generate SSL certificates:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem
```

2. Uncomment HTTPS section in `nginx.conf`

3. Restart nginx:
```bash
docker-compose restart nginx
```

### Secure Passwords

- Change default passwords in `.env`
- Use strong passwords (16+ characters)
- Enable firewall rules
- Use HTTPS in production

## 📊 Monitoring

### View Container Stats
```bash
docker stats
```

### Check Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f code-server
```

### Health Checks
```bash
# Check service health
docker-compose ps
```

## 🧹 Maintenance

### Update Images
```bash
docker-compose pull
docker-compose up -d
```

### Backup Data
```bash
# Backup volumes
docker run --rm -v vscode-container-project_postgres-data:/data \
  -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz /data
```

### Clean Up
```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: deletes data)
docker-compose down -v

# Remove images
docker-compose down --rmi all
```

## 🐛 Troubleshooting

### Code-Server Won't Start
```bash
# Check logs
docker-compose logs code-server

# Verify permissions
chmod -R 755 config/ projects/
```

### Can't Connect to Database
```bash
# Check if service is running
docker-compose ps

# Test connection
docker exec -it dev-postgres psql -U devuser -d devdb
```

### Port Already in Use
```bash
# Find process using port
lsof -i :8080

# Change port in docker-compose.yml
```

## 📚 Project Ideas

1. **Performance Analysis**: Compare containerized vs native VS Code
2. **Multi-language Setup**: Pre-configured containers for Python, Node, Java
3. **CI/CD Integration**: Add Jenkins/GitLab Runner
4. **Remote Development**: Deploy on cloud with secure access
5. **Team Environment**: Shared development environment


## ⚙️ Running with Podman Compose

If you prefer Podman to Docker, this repository includes a Podman-compatible compose file: `podman-compose.yml`.

Key notes before running:

- The Podman compose file omits Docker-specific mounts (like `/var/run/docker.sock`) and Portainer.
- Bind mounts use `:Z` labels to help with SELinux relabeling on systems where SELinux is enabled. This is safe on systems without SELinux.
- Rootless Podman cannot bind to ports below 1024. If you want to use ports 80/443, either run Podman as root (not recommended for everyday use) or change the host ports in `podman-compose.yml` to high ports (for example `8080:80`, `8443:443`).

Quick steps:

1. Install Podman and Podman Compose (Podman v3+ includes `podman compose`).

2. Make the helper script executable and run it (recommended):

```fish
chmod +x run-podman.sh
./run-podman.sh up
```

3. Follow logs:

```fish
./run-podman.sh logs
```

4. To stop and remove resources:

```fish
./run-podman.sh down
```

If you need Docker-in-Docker features from code-server (i.e., building/running Docker images from inside the container), that requires access to a Docker daemon. With Podman that workflow differs; you can either run Docker on the host and mount `/var/run/docker.sock` (not recommended), or adapt your tooling to use Podman inside the container.

If you'd like, I can also:

- Add an alternative `podman-compose.override.yml` with port remappings for rootless usage.
- Re-introduce a Portainer-like UI that works with Podman (requires extra configuration).

