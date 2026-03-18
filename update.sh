#!/bin/bash

# ==============================================================================
# Script Update Manager
# ==============================================================================
# Description: Updates the installation script from GitHub.
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Checking for updates...${NC}"

# Check if we are in a git repository
if [ -d .git ]; then
    echo -e "${CYAN}Pulling latest changes from GitHub...${NC}"
    git pull origin main
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Update successful!${NC}"
        chmod +x *.sh
    else
        echo -e "${RED}Update failed. Please check your internet connection and git configuration.${NC}"
    fi
else
    # Fallback if not a git repo (direct download)
    echo -e "${CYAN}Non-git environment detected. Downloading latest version...${NC}"
    wget -q https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main/install_apache.sh -O install_apache.sh
    wget -q https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main/update.sh -O update.sh
    chmod +x *.sh
    echo -e "${GREEN}Script updated via direct download.${NC}"
fi
