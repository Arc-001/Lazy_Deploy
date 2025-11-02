#!/bin/sh
# Helper script to run the project with Podman Compose
# Usage: ./run-podman.sh [up|down|logs]
# Run WITHOUT sudo for rootless containers, or WITH sudo for rootful containers

COMPOSE_FILE="podman-compose.yml"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

if ! command_exists podman; then
  echo "ERROR: podman is not installed or not in PATH. Install Podman first." >&2
  exit 1
fi

# Check if podman-compose is installed
if ! command_exists podman-compose; then
  echo "WARNING: podman-compose not found. Trying to use 'podman compose' instead." >&2
  echo "For better compatibility, install podman-compose: pip install podman-compose" >&2
  COMPOSE_CMD="podman compose"
else
  COMPOSE_CMD="podman-compose"
fi

# Check whether Podman is responsive
check_podman_ok() {
  podman ps >/dev/null 2>&1
}

if ! check_podman_ok; then
  echo "Podman does not appear to be responding." >&2
  
  # If running as root, just try starting rootful podman service
  if [ "$(id -u)" -eq 0 ]; then
    echo "Running as root. Attempting to start podman system service..." >&2
    systemctl start podman.socket 2>/dev/null || podman system service --time=0 >/dev/null 2>&1 &
  else
    echo "Running as non-root. Attempting to start user podman service..." >&2
    if command_exists systemctl; then
      systemctl --user start podman.socket 2>/dev/null || true
    fi
    podman system service --time=0 >/dev/null 2>&1 &
  fi

  # Wait a few seconds for service to come up
  i=0
  while ! check_podman_ok && [ $i -lt 6 ]; do
    sleep 1
    i=$((i+1))
  done

  if ! check_podman_ok; then
    cat <<EOF >&2
Podman is still not responding after attempting to start service.
Possible remedies:
 - For rootless: systemctl --user start podman.socket
 - For rootful: systemctl start podman.socket (as root)
 - Manually: podman system service --time=0 &
 - Check: podman --version && podman ps

After fixing, re-run this script.
EOF
    exit 1
  fi
fi

ACTION=${1:-up}

if [ "$ACTION" = "up" ]; then
  # Warn about rootless port binding for ports <1024
  if [ "$(id -u)" -ne 0 ]; then
    echo "Note: running as non-root. Binding to ports <1024 (like 80/443) will fail in rootless mode." >&2
    echo "If you need ports 80/443, either run this script with sudo/root or change ports in $COMPOSE_FILE." >&2
  fi
  
  # Disable docker-compose plugin fallback to avoid docker socket issues
  export PODMAN_IGNORE_CGROUPSV1_WARNING=1
  
  echo "Starting services with: $COMPOSE_CMD -f $COMPOSE_FILE up -d"
  $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "Compose command failed with exit code $rc" >&2
    exit $rc
  fi
  echo "Services started. Use '$COMPOSE_CMD -f $COMPOSE_FILE logs -f' to follow logs." 
elif [ "$ACTION" = "down" ]; then
  echo "Stopping services with: $COMPOSE_CMD -f $COMPOSE_FILE down"
  $COMPOSE_CMD -f "$COMPOSE_FILE" down
elif [ "$ACTION" = "logs" ]; then
  $COMPOSE_CMD -f "$COMPOSE_FILE" logs -f
else
  echo "Unknown action: $ACTION"
  echo "Usage: $0 [up|down|logs]"
  exit 2
fi
