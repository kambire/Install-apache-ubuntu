#!/bin/bash
# ==============================================================================
# Script Update Manager (Robust Version)
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}          Apache Management Script - AUTO UPDATER               ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. GIT UPDATE METHOD
if [ -d .git ] && command -v git &> /dev/null; then
    echo -e "${CYAN}Entorno Git detectado. Sincronizando con GitHub...${NC}"
    
    # Force reset to discard any local changes that might cause conflicts
    echo -e "${YELLOW}Limpiando cambios locales y buscando actualizaciones...${NC}"
    # Guarda el hash actual y descarga novedades
    OLD_HASH=$(git rev-parse HEAD 2>/dev/null)
    git fetch origin main &> /dev/null
    git reset --hard origin/main
    
    if [ $? -eq 0 ]; then
        chmod +x *.sh
        NEW_HASH=$(git rev-parse HEAD 2>/dev/null)
        
        echo -e "\n${GREEN}¡Actualización GIT completada con éxito!${NC}"
        
        if [ "$OLD_HASH" != "$NEW_HASH" ]; then
            echo -e "${CYAN}Resumen de cambios desde la última versión:${NC}"
            git diff --stat $OLD_HASH $NEW_HASH
        else
            echo -e "${YELLOW}No hubo descargas nuevas, ya estabas en la última versión.${NC}"
        fi
        
        echo -e "\nVersión actual: $(grep "# Version:" install_apache.sh | awk '{print $3}')"
        echo -e "Ya puedes ejecutar: sudo ./install_apache.sh"
        exit 0
    else
        echo -e "${RED}Error al sincronizar con Git. Intentando descarga directa...${NC}"
    fi
fi

# 2. DIRECT DOWNLOAD FALLBACK
echo -e "${YELLOW}Iniciando descarga directa de los archivos...${NC}"

# Check for download tool
DL_TOOL=""
if command -v curl &> /dev/null; then
    DL_TOOL="curl -sSL -o"
elif command -v wget &> /dev/null; then
    DL_TOOL="wget -q -O"
else
    echo -e "${RED}Error: Ni curl ni wget están instalados. No se puede descargar.${NC}"
    exit 1
fi

# Download files
URL_RAW="https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main"
CACHE_BUSTER="?t=$(date +%s)"
$DL_TOOL install_apache.sh "$URL_RAW/install_apache.sh$CACHE_BUSTER" && \
$DL_TOOL update.sh "$URL_RAW/update.sh$CACHE_BUSTER"

if [ $? -eq 0 ]; then
    chmod +x *.sh
    echo -e "\n${GREEN}¡Descarga directa completada con éxito!${NC}"
    echo -e "Versión actual: $(grep "# Version:" install_apache.sh | awk '{print $3}')"
    echo -e "Ya puedes ejecutar: sudo ./install_apache.sh"
else
    echo -e "${RED}No se pudieron descargar los archivos. Verifica tu conexión.${NC}"
    exit 1
fi
