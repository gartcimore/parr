#!/bin/bash

# Docker Compose Media Server Setup Script
# This script helps configure the environment variables for your media server setup

set -e

# Load utility functions
if [ -f "setup-utils.sh" ]; then
    source setup-utils.sh
else
    echo "Error: setup-utils.sh not found!"
    echo "Please ensure setup-utils.sh is in the same directory as setup.sh"
    exit 1
fi

# Function to generate qBittorrent configuration
generate_qbittorrent_categories() {
    local tv_category="$1"
    local movie_category="$2"
    local music_category="$3"
    local config_dir="$4"
    local data_dir="$5"
    
    echo -e "${BLUE}Generating qBittorrent configuration...${NC}"
    
    # Create qBittorrent config directory if it doesn't exist
    local qbt_config_dir="$config_dir/qbittorrent/qBittorrent"
    mkdir -p "$qbt_config_dir"
    
    # Create categories.json file
    local categories_file="$qbt_config_dir/categories.json"
    
    cat > "$categories_file" << EOF
{
    "$tv_category": {
        "save_path": "$data_dir/torrents/tv"
    },
    "$movie_category": {
        "save_path": "$data_dir/torrents/movies"
    },
    "$music_category": {
        "save_path": "$data_dir/torrents/music"
    }
}
EOF
    
    # Create qBittorrent.conf file with basic configuration
    local config_file="$qbt_config_dir/qBittorrent.conf"
    
    cat > "$config_file" << EOF
[Application]
FileLogger\\Enabled=true
FileLogger\\Path=/config/qBittorrent/logs
FileLogger\\Backup=true
FileLogger\\MaxSizeBytes=66560
FileLogger\\DeleteOld=true
FileLogger\\AgeType=1
FileLogger\\Age=6

[BitTorrent]
Session\\DefaultSavePath=$data_dir/torrents
Session\\TempPath=$data_dir/torrents/incomplete
Session\\TempPathEnabled=true
Session\\UseAlternativeGlobalSpeedLimitTimer=false
Session\\GlobalMaxRatio=-1
Session\\GlobalMaxSeedingMinutes=-1
Session\\QueueingSystemEnabled=true
Session\\MaxActiveDownloads=3
Session\\MaxActiveTorrents=5
Session\\MaxActiveUploads=3

[Preferences]
General\\Locale=en
Downloads\\SavePath=$data_dir/torrents
Downloads\\TempPath=$data_dir/torrents/incomplete
Downloads\\TempPathEnabled=true
Downloads\\UseIncompleteExtension=false
Downloads\\PreAllocation=false
Downloads\\UseAlternativeGlobalSpeedLimitTimer=false
Connection\\PortRangeMin=6881
Connection\\PortRangeMax=6889
Connection\\UPnP=true
Connection\\GlobalDLLimitAlt=0
Connection\\GlobalUPLimitAlt=0
Bittorrent\\MaxRatio=-1
Bittorrent\\MaxRatioAction=0
Bittorrent\\GlobalMaxSeedingMinutes=-1
Bittorrent\\QueueingEnabled=true
Bittorrent\\MaxActiveDownloads=3
Bittorrent\\MaxActiveTorrents=5
Bittorrent\\MaxActiveUploads=3
WebUI\\Enabled=true
WebUI\\Address=*
WebUI\\Port=8080
WebUI\\UseUPnP=false
WebUI\\Username=admin
WebUI\\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\\CSRFProtection=true
WebUI\\ClickjackingProtection=true
WebUI\\SecureCookie=true
WebUI\\MaxAuthenticationFailCount=5
WebUI\\BanDuration=3600
WebUI\\SessionTimeout=3600
WebUI\\AlternativeUIEnabled=false
WebUI\\RootFolder=
WebUI\\HTTPS\\Enabled=false
EOF
    
    if [ -f "$categories_file" ] && [ -f "$config_file" ]; then
        echo -e "${GREEN}qBittorrent configuration created successfully:${NC}"
        echo "  Categories: $categories_file"
        echo "  Config: $config_file"
        echo -e "${YELLOW}Default WebUI credentials: admin/adminadmin${NC}"
    else
        echo -e "${RED}Failed to create qBittorrent configuration${NC}"
    fi
}

echo "========================================="
echo "Docker Compose Media Server Setup"
echo "========================================="
echo ""





# Read current values from .env if it exists
if [ -f ".env" ]; then
    echo -e "${GREEN}Found existing .env file. Loading current values...${NC}"
    load_env_file ".env"
else
    echo -e "${YELLOW}No existing .env file found. Using defaults from .env.sample...${NC}"
    if [ -f ".env.sample" ]; then
        load_env_file ".env.sample"
    fi
fi

echo ""
echo "========================================="
echo "Basic Configuration"
echo "========================================="

# Basic config
prompt_with_default "Timezone (e.g., America/New_York, Europe/Paris):" "${TZ:-Europe/Paris}" "NEW_TZ"
prompt_with_default "Docker config directory (where app configs will be stored):" "${DOCKER_CONFIG_DIR:-/docker/appdata}" "NEW_DOCKER_CONFIG_DIR"
prompt_with_default "Hostname for Traefik (your local domain):" "${HOSTNAME:-media.local}" "NEW_HOSTNAME"

echo ""
echo "========================================="
echo "Installation Type"
echo "========================================="

# Installation type selection
echo -e "${BLUE}Choose installation type:${NC}"
echo "1. Service (systemctl) - Recommended for always-on setup (linux only)"
echo "2. Regular Docker Stack - Manual docker-compose management"
echo ""
read -p "Enter choice (1 or 2) [default: 1]: " install_choice

if [ -z "$install_choice" ] || [ "$install_choice" = "1" ]; then
    NEW_INSTALL_TYPE="service"
    echo -e "${GREEN}Selected: Service installation${NC}"
elif [ "$install_choice" = "2" ]; then
    NEW_INSTALL_TYPE="docker"
    echo -e "${GREEN}Selected: Regular Docker Stack${NC}"
else
    echo -e "${YELLOW}Invalid choice. Defaulting to service installation.${NC}"
    NEW_INSTALL_TYPE="service"
fi

echo ""
echo "========================================="
echo "Security Configuration"
echo "========================================="

# Generate Homarr secret key
# Check if we already have a valid (non-default) key
if [ -n "$HOMARR_SECRET_KEY" ] && [ "$HOMARR_SECRET_KEY" != "your_homarr_secret_key_here" ] && [ "$HOMARR_SECRET_KEY" != "" ]; then
    echo -e "${GREEN}Using existing Homarr encryption key${NC}"
    NEW_HOMARR_SECRET_KEY="$HOMARR_SECRET_KEY"
else
    echo -e "${BLUE}Generating secure encryption key for Homarr...${NC}"
    if command -v openssl >/dev/null 2>&1; then
        NEW_HOMARR_SECRET_KEY=$(openssl rand -hex 32)
        echo -e "${GREEN}Generated 64-character encryption key${NC}"
    else
        echo -e "${YELLOW}OpenSSL not found. Using fallback method...${NC}"
        # Fallback: generate using /dev/urandom if available
        if [ -r /dev/urandom ]; then
            NEW_HOMARR_SECRET_KEY=$(head -c 32 /dev/urandom | xxd -p -c 32)
            echo -e "${GREEN}Generated 64-character encryption key${NC}"
        else
            echo -e "${RED}Cannot generate secure key automatically${NC}"
            prompt_with_default "Homarr encryption key (64 characters):" "${HOMARR_SECRET_KEY:-$(date +%s | sha256sum | head -c 64)}" "NEW_HOMARR_SECRET_KEY"
        fi
    fi
fi

echo ""
echo "========================================="
echo "Media Storage Paths"
echo "========================================="

prompt_with_default "Primary data directory (for media, downloads, etc.):" "${DATA_DIR:-/data}" "NEW_DATA_DIR"

# Set downloads directory
DOWNLOADS_DIR="${NEW_DATA_DIR}/torrents"

echo ""
echo "========================================="
echo "VPN Configuration (for qBittorrent)"
echo "========================================="

prompt_with_default "VPN Type (wireguard or openvpn):" "${VPN_TYPE:-wireguard}" "NEW_VPN_TYPE"
prompt_with_default "VPN Server Countries (comma-separated):" "${SERVER_COUNTRIES:-United States,Canada,United Kingdom}" "NEW_SERVER_COUNTRIES"

echo ""
echo -e "${BLUE}VPN Credentials Configuration:${NC}"
echo -e "${YELLOW}You can configure these now or skip and set them later in the .env file${NC}"
echo ""

# Always ask for OpenVPN credentials (can be skipped)
echo -e "${BLUE}OpenVPN Credentials (for ProtonVPN):${NC}"
prompt_optional "OpenVPN Username (format: username+pmp):" "NEW_OPENVPN_USER" "${OPENVPN_USER}"
prompt_optional "OpenVPN Password:" "NEW_OPENVPN_PASSWORD" "${OPENVPN_PASSWORD}"

# Ask for WireGuard key based on VPN type or always
if [[ $NEW_VPN_TYPE == "wireguard" ]]; then
    echo ""
    echo -e "${BLUE}WireGuard Configuration:${NC}"
    prompt_optional "WireGuard Private Key:" "NEW_WIREGUARD_PRIVATE_KEY" "${WIREGUARD_PRIVATE_KEY}"
else
    # Keep existing WireGuard key if any
    NEW_WIREGUARD_PRIVATE_KEY="${WIREGUARD_PRIVATE_KEY:-your_wireguard_private_key_here}"
fi

# Set default placeholders if values are empty
NEW_OPENVPN_USER="${NEW_OPENVPN_USER:-your_username+pmp}"
NEW_OPENVPN_PASSWORD="${NEW_OPENVPN_PASSWORD:-your_password}"
NEW_WIREGUARD_PRIVATE_KEY="${NEW_WIREGUARD_PRIVATE_KEY:-your_wireguard_private_key_here}"

echo ""
echo "========================================="
echo "qBittorrent Categories"
echo "========================================="

prompt_with_default "TV Shows category:" "sonarr" "QB_CATEGORY_TV"
prompt_with_default "Movies category:" "radarr" "QB_CATEGORY_MOVIE"
prompt_with_default "Music category:" "lidarr" "QB_CATEGORY_MUSIC"

echo ""
echo "========================================="
echo "Writing Configuration"
echo "========================================="

# Write the .env file first so create-volumes.sh can use it
cat > .env << EOF
# Docker Compose Media Server Configuration
# Generated by setup script on $(date)

# Base config
TZ=$NEW_TZ
DATA_DIR=$NEW_DATA_DIR
DOCKER_CONFIG_DIR=$NEW_DOCKER_CONFIG_DIR
INSTALL_TYPE=$NEW_INSTALL_TYPE

# Traefik config
HOSTNAME=$NEW_HOSTNAME

# Homarr config
HOMARR_SECRET_KEY=$NEW_HOMARR_SECRET_KEY

# Gluetun config
VPN_TYPE=$NEW_VPN_TYPE
SERVER_COUNTRIES=$NEW_SERVER_COUNTRIES

# OpenVPN config
OPENVPN_USER=$NEW_OPENVPN_USER
OPENVPN_PASSWORD=$NEW_OPENVPN_PASSWORD

# Wireguard config
WIREGUARD_PRIVATE_KEY=$NEW_WIREGUARD_PRIVATE_KEY
EOF

echo -e "${GREEN}Configuration written to .env file!${NC}"

echo ""
echo "========================================="
echo "Creating Directories"
echo "========================================="

# Run the create-volumes script to create all necessary directories
echo -e "${BLUE}Running create-volumes.sh to create all necessary directories...${NC}"
if [ -f "./create-volumes.sh" ]; then
    chmod +x ./create-volumes.sh
    ./create-volumes.sh
else
    echo -e "${YELLOW}Warning: create-volumes.sh not found. You may need to create directories manually.${NC}"
fi

# Generate qBittorrent categories configuration
generate_qbittorrent_categories "$QB_CATEGORY_TV" "$QB_CATEGORY_MOVIE" "$QB_CATEGORY_MUSIC" "$NEW_DOCKER_CONFIG_DIR" "$NEW_DATA_DIR"

echo ""
echo "========================================="
echo "Service Installation"
echo "========================================="

# Handle service installation if selected
if [ "$NEW_INSTALL_TYPE" = "service" ]; then
    echo -e "${BLUE}Installing as systemd service...${NC}"
    
    # Check if arr.service exists
    if [ ! -f "arr.service" ]; then
        echo -e "${RED}Error: arr.service file not found!${NC}"
        echo -e "${YELLOW}Continuing with setup, but service installation failed.${NC}"
    else
        # Get current directory path
        CURRENT_DIR=$(pwd)
        
        # Create service file with correct WorkingDirectory
        cat > arr.service.tmp << EOF
[Unit]
Description=Arr stack
Requires=docker.service
After=docker.service

[Service]
Restart=always
WorkingDirectory=$CURRENT_DIR
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=default.target
EOF
        
        # Copy service file to systemd directory
        if sudo cp arr.service.tmp /etc/systemd/system/arr.service; then
            echo -e "${GREEN}Service file copied to /etc/systemd/system/arr.service${NC}"
            
            # Clean up temporary file
            rm arr.service.tmp
            
            # Reload systemd and enable the service
            if sudo systemctl daemon-reload && sudo systemctl enable arr.service; then
                echo -e "${GREEN}Service enabled successfully!${NC}"
                echo -e "${BLUE}You can now use:${NC}"
                echo "  sudo systemctl start arr    # Start the service"
                echo "  sudo systemctl stop arr     # Stop the service"
                echo "  sudo systemctl status arr   # Check service status"
            else
                echo -e "${RED}Failed to enable service${NC}"
            fi
        else
            echo -e "${RED}Failed to copy service file. Make sure you have sudo privileges.${NC}"
            rm -f arr.service.tmp
        fi
    fi
else
    echo -e "${BLUE}Skipping service installation (Docker stack mode selected)${NC}"
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}Your media server is now configured with:${NC}"
echo "• Timezone: $NEW_TZ"
echo "• Config Directory: $NEW_DOCKER_CONFIG_DIR"
echo "• Hostname: $NEW_HOSTNAME"
echo "• Data Directory: $NEW_DATA_DIR"
echo "• Downloads Directory: $DOWNLOADS_DIR"
echo "• VPN Type: $NEW_VPN_TYPE"
echo "• Installation Type: $NEW_INSTALL_TYPE"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated .env file if needed"
echo "2. Update your VPN credentials in .env if needed"
if [ "$NEW_INSTALL_TYPE" = "service" ]; then
    echo "3. Start the service: sudo systemctl start arr"
else
    echo "3. Run: docker-compose up -d"
fi
echo "4. Configure your local DNS to point $NEW_HOSTNAME to this machine's IP"
echo ""
echo -e "${GREEN}All directories have been created with proper permissions!${NC}"
echo -e "${YELLOW}If you encounter permission issues, you may need to adjust ownership manually.${NC}"