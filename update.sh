#!/bin/bash
# ==============================================================================
# Script Update Manager (Advanced Beautiful Version)
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
echo "  ___        _          _     _   _          _       _            "
echo " |_ _|_ __  | |_ ___   / \   | | | |_ __  __| | __ _| |_ ___ _ __ "
echo "  | || '_ \ | __/ _ \ / _ \  | | | | '_ \/ _\` |/ _\` | __/ _ \ '__|"
echo "  | || | | || ||  __// ___ \ | |_| | |_) | (_| | (_| | ||  __/ |   "
echo " |___|_| |_| \__\___/_/   \_\ \___/| .__/ \__,_|\__,_|\__\___|_|   "
echo "                                   |_|                             "
echo -e "${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}${BOLD}             SISTEMA INTELIGENTE DE ACTUALIZACIÓN               ${NC}"
echo -e "${BLUE}================================================================${NC}\n"

# 1. GIT UPDATE METHOD
if [ -d .git ] && command -v git &> /dev/null; then
    echo -e "${YELLOW}➤ Conectando con los servidores de GitHub...${NC}"
    
    # Store old commit hash
    OLD_HASH=$(git rev-parse HEAD 2>/dev/null)
    
    # Fetch updates silently
    git fetch origin main &> /dev/null
    
    # Check if we are behind origin/main
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null || git rev-parse origin/main)
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        echo -e "\n${GREEN}${BOLD}        ✔️  TU SISTEMA YA ESTÁ EN LA VERSIÓN MÁS RECIENTE ✔️        ${NC}"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        echo -e "No se detectaron nuevos cambios en el repositorio oficial."
        echo -e "Abriendo el panel de control principal...\n"
        sleep 1
        exec sudo ./install_apache.sh
    fi
    
    echo -e "${PURPLE}➤ Descargando e instalando nueva versión...${NC}"
    git reset --hard origin/main &> /dev/null
    
    if [ $? -eq 0 ]; then
        chmod +x *.sh
        NEW_HASH=$(git rev-parse HEAD 2>/dev/null)
        
        echo -e "\n${GREEN}${BOLD}        🚀  ¡ACTUALIZACIÓN COMPLETADA CON ÉXITO!  🚀        ${NC}"
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${YELLOW}RESUMEN DE LOS CAMBIOS INSTALADOS AHORA MISMO:${NC}\n"
        
        # Beautiful Git Log showing exactly what the user downloaded
        git log --pretty=format:" ${GREEN}●${NC} %C(cyan)%h%Creset - %C(bold white)%s%Creset %C(green)(hace %cr)%Creset" $OLD_HASH..$NEW_HASH
        
        echo -e "\n\n${CYAN}================================================================${NC}"
        echo -e "${GREEN}Abriendo el panel de control actualizado...${NC}\n"
        sleep 2
        exec sudo ./install_apache.sh
    else
        echo -e "\n${RED}❌ Error crítico al sincronizar con Git. Intentando modo seguro...${NC}\n"
    fi
fi

# 2. DIRECT DOWNLOAD FALLBACK
echo -e "${YELLOW}Iniciando descarga directa (Fallback Mode)...${NC}"

# Check for download tool
DL_TOOL=""
if command -v curl &> /dev/null; then
    DL_TOOL="curl -sSL -o"
elif command -v wget &> /dev/null; then
    DL_TOOL="wget -q -O"
else
    echo -e "${RED}❌ Error: Ni curl ni wget están instalados. No se puede descargar.${NC}"
    exit 1
fi

# Download files
URL_RAW="https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main"
CACHE_BUSTER="?t=$(date +%s)"
$DL_TOOL install_apache.sh "$URL_RAW/install_apache.sh$CACHE_BUSTER" && \
$DL_TOOL update.sh "$URL_RAW/update.sh$CACHE_BUSTER"

if [ $? -eq 0 ]; then
    chmod +x *.sh
    echo -e "\n${GREEN}${BOLD}✔️ Descarga directa completada con éxito.${NC}"
    echo -e "${YELLOW}Se han forzado los archivos a su última versión disponible.${NC}\n"
    echo -e "${GREEN}Abriendo el panel de control...${NC}\n"
    sleep 2
    exec sudo ./install_apache.sh
else
    echo -e "${RED}❌ No se pudieron descargar los archivos. Verifica tu conexión.${NC}\n"
    exit 1
fi
