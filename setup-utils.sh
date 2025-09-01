#!/bin/bash

# Setup Utilities for Docker Compose Media Server
# This file contains utility functions used by setup.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    echo -e "${BLUE}$prompt${NC}"
    echo -e "${YELLOW}Current/Default: $default${NC}"
    read -p "Enter value (or press Enter for default): " input
    
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Function to prompt for input without default, allow skip
prompt_optional() {
    local prompt="$1"
    local var_name="$2"
    local current_value="$3"
    
    echo -e "${BLUE}$prompt${NC}"
    if [ -n "$current_value" ] && [ "$current_value" != "your_username+pmp" ] && [ "$current_value" != "your_password" ]; then
        echo -e "${YELLOW}Current value: $current_value${NC}"
    fi
    echo -e "${YELLOW}Press Enter to skip if you don't want to configure this now${NC}"
    read -p "Enter value (or press Enter to skip): " input
    
    if [ -n "$input" ]; then
        eval "$var_name='$input'"
    else
        # Keep existing value or set placeholder
        if [ -n "$current_value" ]; then
            eval "$var_name='$current_value'"
        else
            eval "$var_name=''"
        fi
    fi
}

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

# Function to create directory with proper error handling
create_dir() {
    local dir_path="$1"
    if [ -n "$dir_path" ]; then
        mkdir -p "$dir_path"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Created directory: $dir_path${NC}"
        else
            echo -e "${RED}Failed to create directory: $dir_path${NC}"
            return 1
        fi
    fi
}

# Function to create file with content
create_file() {
    local file_path="$1"
    local content="$2"
    
    if [ -n "$file_path" ]; then
        # Create parent directory if it doesn't exist
        local parent_dir=$(dirname "$file_path")
        if [ ! -d "$parent_dir" ]; then
            mkdir -p "$parent_dir"
        fi
        
        # Write content to file
        echo "$content" > "$file_path"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Created file: $file_path${NC}"
        else
            echo -e "${RED}Failed to create file: $file_path${NC}"
            return 1
        fi
    fi
}