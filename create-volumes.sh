#!/bin/bash

# Script to create all necessary volume directories for docker-compose services
# This script reads the .env file and creates all required directories

set -e  # Exit on any error

# Load utility functions
if [ -f "setup-utils.sh" ]; then
    source setup-utils.sh
else
    echo "Error: setup-utils.sh not found!"
    echo "Please ensure setup-utils.sh is in the same directory as create-volumes.sh"
    exit 1
fi

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

# Note: load_env_file function is now available from setup-utils.sh

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

# Enhanced function to create directory with proper permissions using utility function
create_directory() {
    local dir_path="$1"
    local description="$2"
    
    if [ ! -d "$dir_path" ]; then
        print_status "Creating directory: $dir_path ($description)"
        
        # Use utility function to create directory
        if create_dir "$dir_path"; then
            # Set ownership to user 1000:1000 (PUID:PGID used by most services)
            if sudo chown 1000:1000 "$dir_path" 2>/dev/null; then
                print_status "Set ownership (1000:1000) for: $dir_path"
            else
                print_warning "Could not set ownership for $dir_path"
            fi
            
            # Set appropriate permissions
            if sudo chmod 755 "$dir_path" 2>/dev/null; then
                print_status "Set permissions (755) for: $dir_path"
            else
                print_warning "Could not set permissions for $dir_path"
            fi
        else
            print_error "Could not create directory: $dir_path"
            print_warning "You may need to create this directory manually with appropriate permissions"
        fi
    else
        print_warning "Directory already exists: $dir_path"
    fi
}

# Function to create multiple directories efficiently
create_directories_batch() {
    local base_path="$1"
    shift
    local directories=("$@")
    
    for dir in "${directories[@]}"; do
        local full_path="$base_path/$dir"
        local description=$(basename "$dir")
        create_directory "$full_path" "$description"
    done
}

print_status "Starting directory creation process..."

# Create service config directories
print_status "Creating service configuration directories..."

# Service config directories
service_dirs=(
    "prowlarr/data"
    "radarr"
    "sonarr"
    "bazarr"
    "lidarr"
    "jellyfin"
    "jellyseer"
    "homarr"
    "gluetun"
    "qbittorrent"
)

create_directories_batch "$DOCKER_CONFIG_DIR" "${service_dirs[@]}"

# Create data directories based on .env configuration
print_status "Creating data directories..."

# Create main data directory
create_directory "$DATA_DIR" "Main data directory"

# Create data directories using batch function
print_status "Creating data directories..."

# Torrent directories
print_status "Creating torrent directories..."
torrent_dirs=(
    "torrents"
    "torrents/books"
    "torrents/movies"
    "torrents/music"
    "torrents/tv"
)
create_directories_batch "$DATA_DIR" "${torrent_dirs[@]}"

# Usenet directories
print_status "Creating usenet directories..."
usenet_dirs=(
    "usenet"
    "usenet/incomplete"
    "usenet/complete"
    "usenet/complete/books"
    "usenet/complete/movies"
    "usenet/complete/music"
    "usenet/complete/tv"
)
create_directories_batch "$DATA_DIR" "${usenet_dirs[@]}"

# Final media directories
print_status "Creating final media directories..."
media_dirs=(
    "media"
    "media/books"
    "media/movies"
    "media/music"
    "media/tv"
)
create_directories_batch "$DATA_DIR" "${media_dirs[@]}"

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