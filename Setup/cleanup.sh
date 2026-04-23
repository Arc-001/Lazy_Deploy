#!/usr/bin/env bash
set -euo pipefail

# Ensure whiptail is available (standard on Fedora, but good to check)
if ! command -v whiptail &> /dev/null; then
    echo "This script requires 'whiptail' for the TUI."
    echo "Please install it using: sudo dnf install newt"
    exit 1
fi

# Introductory Message
whiptail --title "Workstation Deep Clean" --msgbox "Welcome to the interactive deep cleaning utility.\n\nYou will be prompted before any action is taken. Sudo privileges will be required for system-level tasks." 12 60

# 1. DNF Cache
if whiptail --title "DNF Cache" --yesno "Clear downloaded packages and metadata?\n\nCommand: sudo dnf clean all" 10 60; then
    echo -e "\n---> Cleaning DNF Cache..."
    sudo dnf clean all
fi

# 2. Flatpak Unused
if whiptail --title "Flatpak Runtimes" --yesno "Remove orphaned and unused Flatpak runtimes?\n\nCommand: flatpak uninstall --unused" 10 60; then
    echo -e "\n---> Removing unused Flatpaks..."
    flatpak uninstall --unused -y
fi

# 3. DNF Autoremove
if whiptail --title "DNF Autoremove" --yesno "Remove orphaned system dependencies?\n\nWARNING: Review the list carefully in the terminal before confirming the prompt that follows." 12 60; then
    echo -e "\n---> Running DNF Autoremove..."
    sudo dnf autoremove
fi

# 4. Cargo / Rust
if command -v cargo &> /dev/null; then
    if whiptail --title "Cargo Cache" --yesno "Clear Rust/Cargo registry and git checkouts?\n\nTarget: ~/.cargo/registry and ~/.cargo/git" 10 60; then
        echo -e "\n---> Cleaning Cargo cache..."
        rm -rf ~/.cargo/registry
        rm -rf ~/.cargo/git
    fi
fi

# 5. Go
if command -v go &> /dev/null; then
    if whiptail --title "Go Module Cache" --yesno "Clear Go downloaded module cache?\n\nCommand: go clean -modcache" 10 60; then
        echo -e "\n---> Cleaning Go cache..."
        go clean -modcache
    fi
fi

# 6. Python / Pip
if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
    if whiptail --title "Pip Cache" --yesno "Clear global Python pip cache?\n\nTarget: ~/.cache/pip" 10 60; then
        echo -e "\n---> Cleaning Pip cache..."
        rm -rf ~/.cache/pip
    fi
fi

# 7. Containers (Podman/Docker)
if command -v podman &> /dev/null; then
    if whiptail --title "Podman Prune" --yesno "Remove ALL unused Podman containers, networks, and dangling images?\n\nCommand: podman system prune -a --volumes" 12 60; then
        echo -e "\n---> Pruning Podman..."
        podman system prune -a --volumes -f
    fi
elif command -v docker &> /dev/null; then
    if whiptail --title "Docker Prune" --yesno "Remove ALL unused Docker containers, networks, and dangling images?\n\nCommand: docker system prune -a --volumes" 12 60; then
        echo -e "\n---> Pruning Docker..."
        docker system prune -a --volumes -f
    fi
fi

# 8. Systemd Journal
if whiptail --title "Systemd Journal" --yesno "Vacuum old system logs, keeping only the last 2 weeks?\n\nCommand: sudo journalctl --vacuum-time=2weeks" 10 60; then
    echo -e "\n---> Vacuuming system logs..."
    sudo journalctl --vacuum-time=2weeks
fi

# 9. NCDU Finale
if whiptail --title "Visual Inspection (ncdu)" --yesno "Cleanup phase complete.\n\nWould you like to launch 'ncdu' to visually inspect your home directory for any remaining large files?" 12 60; then
    clear
    if ! command -v ncdu &> /dev/null; then
        echo "ncdu is not installed. Installing it now via DNF..."
        sudo dnf install -y ncdu
    fi
    
    # Launch ncdu in the home directory
    ncdu ~
else
    whiptail --title "Done" --msgbox "Cleanup complete! Exiting." 8 40
    clear
fi
