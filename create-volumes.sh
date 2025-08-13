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

# Source the .env file to get variables
print_status "Loading environment variables from .env file..."
source .env

# Check if DOCKER_CONFIG_DIR is set
if [ -z "$DOCKER_CONFIG_DIR" ]; then
    print_error "DOCKER_CONFIG_DIR not set in .env file!"
    exit 1
fi

print_status "Using DOCKER_CONFIG_DIR: $DOCKER_CONFIG_DIR"

# Function to create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local service_name="$2"
    
    if [ ! -d "$dir_path" ]; then
        print_status "Creating directory for $service_name: $dir_path"
        
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

# Function to create media directories
create_media_directory() {
    local dir_path="$1"
    local description="$2"
    
    if [ ! -d "$dir_path" ]; then
        print_status "Creating media directory: $dir_path ($description)"
        
        # Try to create directory (with or without sudo)
        if mkdir -p "$dir_path" 2>/dev/null; then
            print_success "Created: $dir_path"
        elif sudo mkdir -p "$dir_path" 2>/dev/null; then
            print_success "Created (with sudo): $dir_path"
            sudo chown 1000:1000 "$dir_path" 2>/dev/null || print_warning "Could not set ownership for $dir_path"
            sudo chmod 755 "$dir_path" 2>/dev/null || print_warning "Could not set permissions for $dir_path"
        else
            print_error "Could not create directory: $dir_path"
            print_warning "You may need to create this directory manually with appropriate permissions"
        fi
    else
        print_warning "Media directory already exists: $dir_path"
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
create_directory "$DOCKER_CONFIG_DIR/qbittorent" "qBittorrent"

# Create media directories based on .env configuration
print_status "Creating media directories..."

# Use MEDIA_DIR from .env if set, otherwise use default
MEDIA_BASE="${MEDIA_DIR:-/media}"
create_media_directory "$MEDIA_BASE" "Main media directory"

# Create downloads directory
DOWNLOADS_BASE="${DOWNLOADS_DIR:-$MEDIA_BASE/downloads}"
create_media_directory "$DOWNLOADS_BASE" "qBittorrent downloads"

# Create downloads subdirectories
create_media_directory "$DOWNLOADS_BASE/complete" "Completed downloads"
create_media_directory "$DOWNLOADS_BASE/incomplete" "Incomplete downloads"

# Create additional mount points if they exist in the docker-compose file
if [ -d "/mnt/dataYmir" ] || grep -q "/mnt/dataYmir" ../docker-compose.yml 2>/dev/null; then
    create_media_directory "/mnt/dataYmir" "Main data mount (Ymir)"
    create_media_directory "/mnt/dataYmir/media" "Jellyfin media (Ymir)"
    create_media_directory "/mnt/dataYmir/downloads" "Downloads (Ymir)"
fi

if [ -d "/mnt/data" ] || grep -q "/mnt/data" ../docker-compose.yml 2>/dev/null; then
    create_media_directory "/mnt/data" "Secondary data mount (Drogo)"
    create_media_directory "/mnt/data/media" "Jellyfin media (Drogo)"
fi

# Create subdirectories for organized media
print_status "Creating organized media subdirectories..."

# Jellyfin media structure
create_media_directory "/mnt/dataYmir/media/movies" "Movies directory"
create_media_directory "/mnt/dataYmir/media/tv" "TV Shows directory"
create_media_directory "/mnt/dataYmir/media/music" "Music directory"

create_media_directory "/mnt/data/media/movies" "Movies directory (Drogo)"
create_media_directory "/mnt/data/media/tv" "TV Shows directory (Drogo)"
create_media_directory "/mnt/data/media/music" "Music directory (Drogo)"

# Download organization
create_media_directory "/mnt/dataYmir/downloads/complete" "Completed downloads"
create_media_directory "/mnt/dataYmir/downloads/incomplete" "Incomplete downloads"

print_status "Setting up directory permissions..."

# Ensure proper permissions for all created directories
sudo chown -R 1000:1000 "$DOCKER_CONFIG_DIR" 2>/dev/null || print_warning "Could not change ownership of $DOCKER_CONFIG_DIR"
sudo chown -R 1000:1000 "/mnt/dataYmir" 2>/dev/null || print_warning "Could not change ownership of /mnt/dataYmir"
sudo chown -R 1000:1000 "/mnt/data" 2>/dev/null || print_warning "Could not change ownership of /mnt/data"

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
echo "  • qBittorrent: $DOCKER_CONFIG_DIR/qbittorent"
echo ""
echo "Media Directories:"
echo "  • Main Data:   /mnt/dataYmir"
echo "  • Media:       /mnt/dataYmir/media"
echo "  • Downloads:   /mnt/dataYmir/downloads"
echo "  • Secondary:   /mnt/data/media"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_success "Volume creation script completed!"
print_status "You can now run 'docker-compose up -d' to start your services."