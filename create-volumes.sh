#!/bin/bash

# Script to create all necessary volume directories for docker-compose services
# This script reads the .env file and creates all required directories

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found! Please create it from .env.sample"
    exit 1
fi

# Function to safely load environment variables from file
load_env_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # Read variables safely, ignoring comments and empty lines
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove leading/trailing whitespace and quotes
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs | sed 's/^["'\'']//' | sed 's/["'\'']*$//')
            
            # Export the variable
            if [ -n "$key" ] && [ -n "$value" ]; then
                export "$key"="$value"
            fi
        done < "$file"
    fi
}

# Load environment variables from .env file
print_status "Loading environment variables from .env file..."
load_env_file ".env"

# Check if required variables are set
if [ -z "$DOCKER_CONFIG_DIR" ]; then
    print_error "DOCKER_CONFIG_DIR not set in .env file!"
    exit 1
fi

if [ -z "$DATA_DIR" ]; then
    print_error "DATA_DIR not set in .env file!"
    exit 1
fi

print_status "Using DOCKER_CONFIG_DIR: $DOCKER_CONFIG_DIR"
print_status "Using DATA_DIR: $DATA_DIR"

# Function to create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local description="$2"
    
    if [ ! -d "$dir_path" ]; then
        print_status "Creating directory: $dir_path ($description)"
        
        # Try to create directory (with or without sudo)
        if mkdir -p "$dir_path" 2>/dev/null; then
            print_success "Created: $dir_path"
        elif sudo mkdir -p "$dir_path" 2>/dev/null; then
            print_success "Created (with sudo): $dir_path"
            # Set ownership to user 1000:1000 (PUID:PGID used by most services)
            sudo chown 1000:1000 "$dir_path" 2>/dev/null || print_warning "Could not set ownership for $dir_path"
            # Set appropriate permissions
            sudo chmod 755 "$dir_path" 2>/dev/null || print_warning "Could not set permissions for $dir_path"
        else
            print_error "Could not create directory: $dir_path"
            print_warning "You may need to create this directory manually with appropriate permissions"
        fi
    else
        print_warning "Directory already exists: $dir_path"
    fi
}

print_status "Starting directory creation process..."

# Create service config directories
print_status "Creating service configuration directories..."

create_directory "$DOCKER_CONFIG_DIR/prowlarr/data" "Prowlarr"
create_directory "$DOCKER_CONFIG_DIR/radarr" "Radarr"
create_directory "$DOCKER_CONFIG_DIR/sonarr" "Sonarr"
create_directory "$DOCKER_CONFIG_DIR/bazarr" "Bazarr"
create_directory "$DOCKER_CONFIG_DIR/lidarr" "Lidarr"
create_directory "$DOCKER_CONFIG_DIR/jellyfin" "Jellyfin"
create_directory "$DOCKER_CONFIG_DIR/jellyseer" "Jellyseer"
create_directory "$DOCKER_CONFIG_DIR/homarr" "Homarr"
create_directory "$DOCKER_CONFIG_DIR/gluetun" "Gluetun"
create_directory "$DOCKER_CONFIG_DIR/qbittorrent" "qBittorrent"

# Create data directories based on .env configuration
print_status "Creating data directories..."

# Create main data directory
create_directory "$DATA_DIR" "Main data directory"

# Create torrent directories
print_status "Creating torrent directories..."
create_directory "$DATA_DIR/torrents" "Torrent downloads"
create_directory "$DATA_DIR/torrents/books" "Torrent books"
create_directory "$DATA_DIR/torrents/movies" "Torrent movies"
create_directory "$DATA_DIR/torrents/music" "Torrent music"
create_directory "$DATA_DIR/torrents/tv" "Torrent TV shows"

# Create usenet directories
print_status "Creating usenet directories..."
create_directory "$DATA_DIR/usenet" "Usenet downloads"
create_directory "$DATA_DIR/usenet/incomplete" "Usenet incomplete downloads"
create_directory "$DATA_DIR/usenet/complete" "Usenet complete downloads"
create_directory "$DATA_DIR/usenet/complete/books" "Usenet books"
create_directory "$DATA_DIR/usenet/complete/movies" "Usenet movies"
create_directory "$DATA_DIR/usenet/complete/music" "Usenet music"
create_directory "$DATA_DIR/usenet/complete/tv" "Usenet TV shows"

# Create final media directories
print_status "Creating final media directories..."
create_directory "$DATA_DIR/media" "Final media storage"
create_directory "$DATA_DIR/media/books" "Books library"
create_directory "$DATA_DIR/media/movies" "Movies library"
create_directory "$DATA_DIR/media/music" "Music library"
create_directory "$DATA_DIR/media/tv" "TV shows library"

# Create backup directory
print_status "Creating backup directory..."
create_directory "$DATA_DIR/parr_backup" "Configuration backups"

print_status "Setting up directory permissions..."

# Ensure proper permissions for all created directories
sudo chown -R 1000:1000 "$DOCKER_CONFIG_DIR" 2>/dev/null || print_warning "Could not change ownership of $DOCKER_CONFIG_DIR"
sudo chown -R 1000:1000 "$DATA_DIR" 2>/dev/null || print_warning "Could not change ownership of $DATA_DIR"

print_success "All directories created successfully!"

# Display summary
print_status "Directory creation summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Service Configuration Directories:"
echo "  • Prowlarr:    $DOCKER_CONFIG_DIR/prowlarr/data"
echo "  • Radarr:      $DOCKER_CONFIG_DIR/radarr"
echo "  • Sonarr:      $DOCKER_CONFIG_DIR/sonarr"
echo "  • Bazarr:      $DOCKER_CONFIG_DIR/bazarr"
echo "  • Lidarr:      $DOCKER_CONFIG_DIR/lidarr"
echo "  • Jellyfin:    $DOCKER_CONFIG_DIR/jellyfin"
echo "  • Jellyseer:   $DOCKER_CONFIG_DIR/jellyseer"
echo "  • Homarr:      $DOCKER_CONFIG_DIR/homarr"
echo "  • Gluetun:     $DOCKER_CONFIG_DIR/gluetun"
echo "  • qBittorrent: $DOCKER_CONFIG_DIR/qbittorrent"
echo ""
echo "Data Directories:"
echo "  • Main Data:   $DATA_DIR"
echo "  • Torrents:    $DATA_DIR/torrents/{books,movies,music,tv}"
echo "  • Usenet:      $DATA_DIR/usenet/{incomplete,complete}"
echo "  • Media:       $DATA_DIR/media/{books,movies,music,tv}"
echo "  • Backups:     $DATA_DIR/parr_backup"
if [ -d "/mnt/data" ]; then
echo "  • Secondary:   /mnt/data/media"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_success "Volume creation script completed!"
print_status "You can now run 'docker-compose up -d' to start your services."