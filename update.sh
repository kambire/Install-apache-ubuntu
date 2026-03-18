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
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}          Apache Management Script Update Tool                  ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed. Cannot update.${NC}"
    exit 1
fi

# Check if it's a git repository
if [ -d .git ]; then
    echo -e "${CYAN}Checking for updates on GitHub (via Git)...${NC}"
    git fetch origin &> /dev/null
    
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u})

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo -e "${GREEN}The script is already up to date!${NC}"
        exit 0
    fi

    echo -e "${YELLOW}Updates found!${NC}"
    echo -e "${CYAN}Summary of changes:${NC}"
    git log --oneline --graph --max-count=5 HEAD..@{u}
    
    echo -e "\n${CYAN}Applying updates...${NC}"
else
    echo -e "${YELLOW}Non-git environment detected (manual install).${NC}"
    echo -e "${CYAN}Updating files from GitHub...${NC}"
fi

# Progress bar function
show_progress() {
    local duration=$1
    local columns=$(tput cols)
    local width=$((columns - 20))
    local progress=0
    
    while [ $progress -le 100 ]; do
        local completed=$((progress * width / 100))
        local remaining=$((width - completed))
        printf "\r${BLUE}[${GREEN}"
        printf "%${completed}s" | tr ' ' '#'
        printf "${RED}"
        printf "%${remaining}s" | tr ' ' '-'
        printf "${BLUE}] ${progress}%%${NC}"
        progress=$((progress + 10))
        sleep 0.2
    done
    echo -e "\n"
}

show_progress 2

if [ -d .git ]; then
    git pull origin main
    if [ $? -eq 0 ]; then
        chmod +x install_apache.sh update.sh
        echo -e "${GREEN}================================================================${NC}"
        echo -e "${GREEN}       Script updated successfully to the latest version!      ${NC}"
        echo -e "${GREEN}================================================================${NC}"
    else
        echo -e "${RED}Error during git pull. Please check manually.${NC}"
        exit 1
    fi
else
    wget -q https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main/install_apache.sh -O install_apache.sh
    wget -q https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main/update.sh -O update.sh
    chmod +x *.sh
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}   Script updated successfully via direct download!           ${NC}"
    echo -e "${GREEN}================================================================${NC}"
fi
