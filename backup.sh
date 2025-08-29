#!/bin/bash

# Parr Stack Backup Script
# This script backs up the configuration data for the Parr media stack

set -e

echo "========================================="
echo "Docker Compose Media Server Backup"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    print_error ".env file not found in current directory"
    exit 1
fi

# Check if setup-utils.sh exists and source it
if [[ ! -f "setup-utils.sh" ]]; then
    print_error "setup-utils.sh not found in current directory"
    exit 1
fi

# Check if stack-utils.sh exists and source it
if [[ ! -f "stack-utils.sh" ]]; then
    print_error "stack-utils.sh not found in current directory"
    exit 1
fi

# Source the utility functions
source setup-utils.sh
source stack-utils.sh

# Load environment variables from .env file
load_env_file ".env"

# Validate required variables
if [[ -z "$DOCKER_CONFIG_DIR" ]]; then
    print_error "DOCKER_CONFIG_DIR not found in .env file"
    exit 1
fi

if [[ -z "$DATA_DIR" ]]; then
    print_error "DATA_DIR not found in .env file"
    exit 1
fi

if [[ ! -d "$DOCKER_CONFIG_DIR" ]]; then
    print_error "DOCKER_CONFIG_DIR ($DOCKER_CONFIG_DIR) does not exist"
    exit 1
fi

# Create backup directory if it doesn't exist
BACKUP_DIR="$DATA_DIR/parr_backup"
if [[ ! -d "$BACKUP_DIR" ]]; then
    print_status "Creating backup directory: $BACKUP_DIR"
    if mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        print_status "Backup directory created successfully"
    elif sudo mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        print_status "Backup directory created with sudo"
        sudo chown 1000:1000 "$BACKUP_DIR" 2>/dev/null || print_warning "Could not set ownership for backup directory"
        sudo chmod 755 "$BACKUP_DIR" 2>/dev/null || print_warning "Could not set permissions for backup directory"
    else
        print_error "Failed to create backup directory: $BACKUP_DIR"
        exit 1
    fi
fi

# Generate timestamp for backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="parr_${TIMESTAMP}.tar.gz"

print_status "Starting backup process..."
print_status "Config directory: $DOCKER_CONFIG_DIR"
print_status "Backup directory: $BACKUP_DIR"
print_status "Backup filename: $BACKUP_FILENAME"

# Stack management functions are now in stack-utils.sh

echo "========================================="
echo "Starting Backup Process"
echo "========================================="
echo ""

# Stop the stack
stop_stack

# Function to extract config folders from docker-compose.yml volume mounts
get_config_folders_from_volumes() {
    if [[ ! -f "docker-compose.yml" ]]; then
        print_error "docker-compose.yml not found in current directory"
        return 1
    fi
    
    local config_folders=()
    
    # Parse docker-compose.yml for volume mounts using DOCKER_CONFIG_DIR
    while IFS= read -r line; do
        # Look for volume lines that contain ${DOCKER_CONFIG_DIR}/something:/something
        if [[ $line =~ -[[:space:]]*\$\{DOCKER_CONFIG_DIR\}/([^:]+): ]]; then
            local folder_path="${BASH_REMATCH[1]}"
            config_folders+=("$folder_path")
        fi
    done < docker-compose.yml
    
    # Remove duplicates and sort
    printf '%s\n' "${config_folders[@]}" | sort -u
}

# Function to get config folders that actually exist
get_existing_config_folders() {
    local all_folders=($(get_config_folders_from_volumes))
    local existing_folders=()
    
    for folder in "${all_folders[@]}"; do
        local config_path="$DOCKER_CONFIG_DIR/$folder"
        
        if [[ -d "$config_path" ]]; then
            existing_folders+=("$folder")
            print_status "Found config folder: $folder" >&2
        else
            print_warning "Config folder not found: $folder (skipping)" >&2
        fi
    done
    
    printf '%s\n' "${existing_folders[@]}"
}

# Create the backup
print_status "Analyzing docker-compose.yml for DOCKER_CONFIG_DIR volume mounts..."

# Get list of services with existing config folders
CONFIG_FOLDERS=($(get_existing_config_folders))

if [[ ${#CONFIG_FOLDERS[@]} -eq 0 ]]; then
    print_error "No service config folders found to backup"
    start_stack
    exit 1
fi

print_status "Will backup ${#CONFIG_FOLDERS[@]} config folders: ${CONFIG_FOLDERS[*]}"

# Change to DOCKER_CONFIG_DIR to create relative paths in tar
if cd "$DOCKER_CONFIG_DIR"; then
    # Create tar with specific folders, excluding cache directories
    TAR_EXCLUDES=(
        "--exclude=*/cache"
        "--exclude=*/cache/*"
        "--exclude=*/Cache"
        "--exclude=*/Cache/*"
        "--exclude=*/logs"
        "--exclude=*/logs/*"
        "--exclude=*/log"
        "--exclude=*/log/*"
        "--exclude=*/Logs"
        "--exclude=*/Logs/*"
        "--exclude=*/Log"
        "--exclude=*/Log/*"
        "--exclude=*/tmp"
        "--exclude=*/tmp/*"
        "--exclude=*/temp"
        "--exclude=*/temp/*"
        "--exclude=*/Temp"
        "--exclude=*/Temp/*"
        "--exclude=*/transcodes"
        "--exclude=*/transcodes/*"
        "--exclude=*/metadata/library"
        "--exclude=*/metadata/library/*"
        "--exclude=*.log"
        "--exclude=*.tmp"
    )
    
    if tar -czf "$BACKUP_DIR/$BACKUP_FILENAME" "${TAR_EXCLUDES[@]}" "${CONFIG_FOLDERS[@]}"; then
        print_status "Backup created successfully: $BACKUP_DIR/$BACKUP_FILENAME"
        
        # Show backup size
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILENAME" | cut -f1)
        print_status "Backup size: $BACKUP_SIZE"
        
        # Show what was backed up
        print_status "Backed up config folders:"
        for folder in "${CONFIG_FOLDERS[@]}"; do
            if [[ -d "$folder" ]]; then
                folder_size=$(du -sh "$folder" 2>/dev/null | cut -f1 || echo "unknown")
                print_status "  - $folder ($folder_size)"
            fi
        done
        
    else
        print_error "Failed to create backup"
        start_stack
        exit 1
    fi
else
    print_error "Failed to change to config directory: $DOCKER_CONFIG_DIR"
    start_stack
    exit 1
fi

# Return to original directory
cd - > /dev/null

# Start the stack
start_stack

echo ""
echo "========================================="
echo "Backup Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}Your media server configuration has been backed up successfully!${NC}"
echo ""
print_status "Backup location: $BACKUP_DIR/$BACKUP_FILENAME"
echo ""
echo -e "${YELLOW}Note: This backup contains only configuration data, not media files.${NC}"