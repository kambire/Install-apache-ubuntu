#!/bin/bash
# Version: 1.5.6 (PHP Extension Detection)
# ==============================================================================

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run as root (sudo bash install_apache.sh)${NC}"
  exit 1
fi

# OS Detection
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}Error: Cannot detect OS. This script is intended for Ubuntu/Debian.${NC}"
    exit 1
fi

if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo -e "${YELLOW}Warning: This script was designed for Ubuntu/Debian. You are running $OS $VER.${NC}"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Ensure whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo -e "${YELLOW}Installing whiptail for the interactive menu...${NC}"
    apt-get update && apt-get install -y whiptail
fi

# ==============================================================================
# UI Helper Functions (Robust version)
# ==============================================================================

# Check if whiptail is working correctly
function check_ui_support() {
    if [ -z "$TERM" ] || [ "$TERM" == "dumb" ]; then
         return 1
    fi
    # Try a non-interactive whiptail call to see if it works
    whiptail --version &>/dev/null
    return $?
}

UI_WORKS=0
check_ui_support || UI_WORKS=1

function msg_box() {
    if [ $UI_WORKS -eq 0 ]; then
        whiptail --title "$1" --msgbox "$2" 10 60 2>/dev/null
    else
        echo -e "${BLUE}--- $1 ---${NC}\n$2\n${BLUE}----------${NC}"
        read -p "Presiona Enter para continuar..."
    fi
}

function input_box() {
    if [ $UI_WORKS -eq 0 ]; then
        local result
        local exit_code
        result=$(whiptail --title "$1" --inputbox "$2" 10 60 "$3" 3>&1 1>&2 2>/dev/null)
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "$result"
            return
        elif [ $exit_code -eq 1 ]; then
            echo ""
            return
        fi
        UI_WORKS=1
    fi
    # Text mode fallback
    echo -e "${BLUE}--- $1 ---${NC}"
    read -p "$2 [$3]: " result
    echo "${result:-$3}"
}

function menu() {
    local title=$1
    local text=$2
    shift 2
    if [ $UI_WORKS -eq 0 ]; then
        local result
        local exit_code
        result=$(whiptail --title "$title" --menu "$text" 23 75 15 "$@" 3>&1 1>&2 2>/dev/null)
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "$result"
            return
        elif [ $exit_code -eq 1 ]; then
            echo ""
            return
        fi
        UI_WORKS=1
    fi
    # Text mode fallback
    echo -e "${BLUE}--- $title ---${NC}"
    echo "$text"
    local options=("$@")
    for ((i=0; i<${#options[@]}; i+=2)); do
        echo "  ${options[i]}) ${options[i+1]}"
    done
    read -p "Selecciona una opción: " result
    echo "$result"
}

function checklist() {
    local title=$1
    local text=$2
    shift 2
    if [ $UI_WORKS -eq 0 ]; then
        local result
        local exit_code
        result=$(whiptail --title "$title" --checklist "$text" 20 70 12 "$@" 3>&1 1>&2 2>/dev/null)
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "$result"
            return
        elif [ $exit_code -eq 1 ]; then
            echo ""
            return
        fi
        UI_WORKS=1
    fi
    # Text mode fallback
    echo -e "${BLUE}--- $title ---${NC}"
    echo "$text (Escribe los valores separados por espacio)"
    local options=("$@")
    for ((i=0; i<${#options[@]}; i+=3)); do
        echo "  ${options[i]}) ${options[i+1]} [${options[i+2]}]"
    done
    read -p "Opciones: " result
    echo "$result"
}

function yes_no() {
    if [ $UI_WORKS -eq 0 ]; then
        whiptail --title "$1" --yesno "$2" 10 60 2>/dev/null
        local exit_code=$?
        if [ $exit_code -le 1 ]; then
            return $exit_code
        fi
        UI_WORKS=1
    fi
    # Text mode fallback
    echo -e "${BLUE}--- $1 ---${NC}"
    read -p "$2 (y/n): " result
    [[ $result =~ ^[Yy]$ ]] && return 0
    return 1
}

# ==============================================================================
# Core Installation Functions
# ==============================================================================

function install_apache_php() {
    msg_box "Instalación de Apache y PHP" "Se instalará Apache y las versiones de PHP que selecciones. Para usar múltiples versiones, se instalará PHP-FPM."
    
    # PHP Version Selection (Checklist for multiple)
    PHP_VERSIONS=$(checklist "Seleccionar Versiones de PHP" "Elige las versiones de PHP a instalar (Espacio para marcar):" \
        "8.4" "PHP 8.4 (Latest)" ON \
        "8.3" "PHP 8.3" OFF \
        "8.2" "PHP 8.2" OFF \
        "8.1" "PHP 8.1" OFF \
        "8.0" "PHP 8.0" OFF \
        "7.4" "PHP 7.4 (Legacy)" OFF \
        "7.3" "PHP 7.3" OFF \
        "7.2" "PHP 7.2" OFF \
        "7.1" "PHP 7.1" OFF \
        "7.0" "PHP 7.0" OFF \
        "5.6" "PHP 5.6 (Old Legacy)" OFF)
    
    [ -z "$PHP_VERSIONS" ] && return

    echo -e "${CYAN}Agregando repositorio de PHP (PPA)...${NC}"
    apt-get update && apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update

    echo -e "${CYAN}Instalando Apache...${NC}"
    apt-get install -y apache2 libapache2-mod-fcgid
    
    # Enable necessary modules for FPM/Proxy
    a2enmod proxy proxy_http proxy_fcgi setenvif rewrite ssl headers
    
    for ver in $PHP_VERSIONS; do
        ver=$(echo $ver | sed 's/"//g')
        echo -e "${CYAN}Instalando PHP $ver y PHP-FPM...${NC}"
        apt-get install -y "php$ver" "php$ver-fpm" "php$ver-common" "php$ver-mysql" "php$ver-xml" "php$ver-xmlrpc" "php$ver-curl" "php$ver-gd" "php$ver-imagick" "php$ver-cli" "php$ver-dev" "php$ver-imap" "php$ver-mbstring" "php$ver-opcache" "php$ver-soap" "php$ver-zip" "php$ver-intl" "php$ver-bcmath"
        systemctl enable "php$ver-fpm"
        systemctl start "php$ver-fpm"
    done

    systemctl restart apache2
    msg_box "Éxito" "Apache y las versiones de PHP ($PHP_VERSIONS) han sido instaladas.\nSe ha configurado PHP-FPM para permitir el uso de múltiples versiones."
}

function manage_modules() {
    msg_box "Gestión de Módulos" "Los módulos de Apache añaden funciones adicionales al servidor (como reescritura de URL o soporte SSL). Selecciona los que quieras activar."
    MODS=$(checklist "Apache Modules" "Select the modules you want to enable (Space to toggle, Up/Down to scroll):" \
        "rewrite" "Redirects & Friendly URLs (URL Rewrite)" ON \
        "ssl" "Strong cryptography (SSL/TLS)" ON \
        "proxy_fcgi" "FastCGI support for proxy (REQUIRED for Multi-PHP)" ON \
        "setenvif" "Environment variables based on request (REQUIRED for Multi-PHP)" ON \
        "headers" "HTTP Header manipulation" OFF \
        "proxy" "Multi-protocol proxy/gateway server" OFF \
        "proxy_http" "Proxy HTTP protocol support" OFF \
        "proxy_balancer" "Load balancing support for proxy" OFF \
        "proxy_connect" "CONNECT request handling (HTTPS proxying)" OFF \
        "proxy_http2" "HTTP/2 support module for proxy" OFF \
        "http2" "Support for the HTTP/2 transport layer" OFF \
        "expires" "Generation of Expires and Cache-Control headers" OFF \
        "deflate" "Gzip/Compression support" OFF \
        "brotli" "Brotli compression support" OFF \
        "env" "Environment variables modification" OFF \
        "mime" "Mime types and extension management" OFF \
        "vhost_alias" "Dynamic mass virtual hosting" OFF \
        "actions" "Execute CGI scripts based on media type" OFF \
        "alias" "Mapping and URL redirection" OFF \
        "allowmethods" "Restrict what HTTP methods can be used" OFF \
        "auth_basic" "Basic HTTP authentication" OFF \
        "auth_digest" "User authentication using MD5 Digest" OFF \
        "auth_form" "Form authentication" OFF \
        "authn_dbd" "User authentication using SQL database" OFF \
        "authn_dbm" "User authentication using DBM files" OFF \
        "authn_file" "User authentication using text files" OFF \
        "authn_socache" "Cache of authentication credentials" OFF \
        "authz_dbd" "Group Authorization and Login using SQL" OFF \
        "authz_dbm" "Group authorization using DBM files" OFF \
        "authz_groupfile" "Group authorization using plaintext files" OFF \
        "authz_host" "Group authorizations based on host/IP" OFF \
        "authz_owner" "Authorization based on file ownership" OFF \
        "authz_user" "User Authorization" OFF \
        "autoindex" "Generates directory indexes automatically" OFF \
        "cache" "RFC 2616 compliant HTTP caching filter" OFF \
        "cache_disk" "Disk based storage for the caching filter" OFF \
        "cgi" "Execution of CGI scripts" OFF \
        "cgid" "Execution of CGI scripts using external daemon" OFF \
        "dav" "Distributed Authoring and Versioning (WebDAV)" OFF \
        "dav_fs" "Filesystem provider for mod_dav" OFF \
        "dbd" "Manages SQL database connections" OFF \
        "ext_filter" "Pass response through external program" OFF \
        "file_cache" "Caches static list of files in memory" OFF \
        "filter" "Context-sensitive smart filter configuration" OFF \
        "include" "Server Side Includes (SSI) support" OFF \
        "info" "Overview of the server configuration" OFF \
        "ldap" "LDAP connection pooling and result caching" OFF \
        "log_debug" "Additional configurable debug logging" OFF \
        "log_forensic" "Forensic Logging of requests" OFF \
        "lua" "Lua hooks into request processing" OFF \
        "macro" "Macros within configuration files" OFF \
        "md" "Managed domains (ACME/Let's Encrypt support)" OFF \
        "ratelimit" "Bandwidth Rate Limiting for Clients" OFF \
        "remoteip" "Original client IP from proxies/balancers" OFF \
        "reqtimeout" "Set timeout for receiving requests" OFF \
        "sed" "Filter content using sed syntax" OFF \
        "session" "Session support" OFF \
        "session_cookie" "Cookie based session support" OFF \
        "session_crypto" "Session encryption support" OFF \
        "setenvif" "Set env variables based on request traits" OFF \
        "socache_redis" "Redis based shared object cache" OFF \
        "socache_shmcb" "shmcb based shared object cache" OFF \
        "speling" "Attempts to correct minor URL misspellings" OFF \
        "status" "Information on server activity/performance" OFF \
        "substitute" "Search and replace on response bodies" OFF \
        "suexec" "Run CGI scripts as specified user/group" OFF \
        "unique_id" "Unique identifier for each request" OFF \
        "userdir" "User-specific directories (~user)" OFF \
        "usertrack" "Clickstream logging of user activity" OFF \
        "version" "Version dependent configuration" OFF \
        "xml2enc" "Internationalisation support for libxml2")
    
    if [ -n "$MODS" ]; then
        echo -e "${CYAN}Enabling selected modules...${NC}"
        # Remove quotes and spaces from the whiptail output
        MODS=$(echo $MODS | sed 's/"//g')
        for mod in $MODS; do
            a2enmod "$mod"
        done
        systemctl restart apache2
        msg_box "Success" "The selected modules have been enabled."
    fi
}

function manage_extensions() {
    msg_box "Extensiones PHP" "Aquí puedes seleccionar las extensiones que desees. El script detectará las que ya tienes instaladas y las marcará automáticamente."

    # 1. Detect installed PHP versions
    INSTALLED_PHP=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$')
    if [ -z "$INSTALLED_PHP" ]; then
        PHP_VERS_LIST=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
        DETECTION_VER=$PHP_VERS_LIST
    else
        PHP_OPTIONS=("TODAS" "Todas las versiones instaladas")
        for v in $INSTALLED_PHP; do
            PHP_OPTIONS+=("$v" "PHP version $v")
        done
        PHP_VERS_CHOICE=$(menu "Seleccionar PHP" "Elige en qué versión quieres gestionar las extensiones:" "${PHP_OPTIONS[@]}")
        [ -z "$PHP_VERS_CHOICE" ] && return
        
        if [ "$PHP_VERS_CHOICE" == "TODAS" ]; then
            PHP_VERS_LIST=$INSTALLED_PHP
            DETECTION_VER=$(echo $INSTALLED_PHP | awk '{print $1}') # Use first for detection
        else
            PHP_VERS_LIST=$PHP_VERS_CHOICE
            DETECTION_VER=$PHP_VERS_CHOICE
        fi
    fi

    # 2. Get list of currently installed modules for detection
    INSTALLED_MODS=$(php$DETECTION_VER -m 2>/dev/null | tr '[:upper:]' '[:lower:]')

    # 3. Define a helper to check status
    function check_ext() {
        if echo "$INSTALLED_MODS" | grep -qpx "$1"; then echo "ON"; else echo "OFF"; fi
    }

    # checklist
    EXTS=$(checklist "PHP Extensions ($DETECTION_VER)" "Selecciona las extensiones (Espacio para marcar/desmarcar):" \
        "amqp" "AMQP protocol" $(check_ext "amqp") \
        "apcu" "APCu cache" $(check_ext "apcu") \
        "bcmath" "High precision math" $(check_ext "bcmath") \
        "bz2" "Bzip2 compression" $(check_ext "bz2") \
        "calendar" "Calendar conversion" $(check_ext "calendar") \
        "curl" "CURL HTTP client" $(check_ext "curl") \
        "dba" "Database abstraction" $(check_ext "dba") \
        "dom" "DOM support" $(check_ext "dom") \
        "enchant" "Spell checking" $(check_ext "enchant") \
        "exif" "Image metadata" $(check_ext "exif") \
        "ffi" "Foreign Function Interface" $(check_ext "ffi") \
        "fileinfo" "Fileinfo support" $(check_ext "fileinfo") \
        "filter" "Filter input" $(check_ext "filter") \
        "ftp" "FTP functions" $(check_ext "ftp") \
        "gd" "GD Image library" $(check_ext "gd") \
        "gettext" "Translation support" $(check_ext "gettext") \
        "gmp" "GNU Multiple Precision" $(check_ext "gmp") \
        "gnupg" "GnuPG support" $(check_ext "gnupg") \
        "grpc" "gRPC support" $(check_ext "grpc") \
        "igbinary" "Binary serialization" $(check_ext "igbinary") \
        "imagick" "ImageMagick library" $(check_ext "imagick") \
        "imap" "IMAP/POP3 support" $(check_ext "imap") \
        "intl" "Internationalization" $(check_ext "intl") \
        "ldap" "LDAP support" $(check_ext "ldap") \
        "mbstring" "Multibyte string" $(check_ext "mbstring") \
        "mcrypt" "Mcrypt encryption" $(check_ext "mcrypt") \
        "memcached" "Memcached support" $(check_ext "memcached") \
        "mongodb" "MongoDB driver" $(check_ext "mongodb") \
        "mysqli" "MySQLi support" $(check_ext "mysqli") \
        "mysqlnd" "MySQL Native Driver" $(check_ext "mysqlnd") \
        "odbc" "ODBC support" $(check_ext "odbc") \
        "opcache" "Opcode caching" $(check_ext "opcache") \
        "pdo" "PDO core" $(check_ext "pdo") \
        "pdo_mysql" "PDO MySQL" $(check_ext "pdo_mysql") \
        "pdo_pgsql" "PDO Postgres" $(check_ext "pdo_pgsql") \
        "pdo_sqlite" "PDO SQLite" $(check_ext "pdo_sqlite") \
        "pgsql" "PostgreSQL support" $(check_ext "pgsql") \
        "posix" "POSIX functions" $(check_ext "posix") \
        "pspell" "Pspell support" $(check_ext "pspell") \
        "readline" "Readline support" $(check_ext "readline") \
        "redis" "Redis cache support" $(check_ext "redis") \
        "soap" "SOAP protocol" $(check_ext "soap") \
        "sockets" "Socket support" $(check_ext "sockets") \
        "sodium" "Sodium encryption" $(check_ext "sodium") \
        "sqlite3" "SQLite database" $(check_ext "sqlite3") \
        "sqlsrv" "MS SQL Server" $(check_ext "sqlsrv") \
        "ssh2" "SSH2 support" $(check_ext "ssh2") \
        "tidy" "Tidy support" $(check_ext "tidy") \
        "xml" "XML support" $(check_ext "xml") \
        "xsl" "XSLT support" $(check_ext "xsl") \
        "yaml" "YAML support" $(check_ext "yaml") \
        "zip" "Zip file handling" $(check_ext "zip"))

    if [ -n "$EXTS" ]; then
        EXTS=$(echo $EXTS | sed 's/"//g')
        for pver in $PHP_VERS_LIST; do
            echo -e "${CYAN}Gestionando extensiones para PHP $pver...${NC}"
            APT_EXTS=""
            for ext in $EXTS; do
                APT_EXTS="$APT_EXTS php$pver-$ext"
            done
            apt-get install -y $APT_EXTS 2>/dev/null || apt-get install -y $(echo $EXTS | sed "s/ / php-/g" | sed "s/^/php-/") 2>/dev/null
            systemctl restart "php$pver-fpm" 2>/dev/null
        done
        systemctl restart apache2
        msg_box "Éxito" "Las extensiones seleccionadas han sido procesadas correctamente."
    fi
}

function install_certbot() {
    msg_box "Instalación de Certbot" "Certbot es una herramienta para automatizar el uso de certificados SSL de Let's Encrypt, permitiendo que tu sitio sea seguro (HTTPS) de forma gratuita.\n\nSe recomienda el uso de 'snap' en Ubuntu para una versión más actualizada."
    
    echo -e "${CYAN}Verificando estado de Certbot...${NC}"
    
    # 1. Attempt snap installation if on Ubuntu and snap exists
    if command -v snap &> /dev/null && [[ "$OS" == "ubuntu" ]]; then
        echo -e "${CYAN}Instalando Certbot vía Snap (Método recomendado)...${NC}"
        # Remove any potential apt conflicts
        apt-get remove -y certbot python3-certbot-apache 2>/dev/null
        
        snap install --classic certbot
        if [ ! -f /usr/bin/certbot ]; then
            ln -s /snap/bin/certbot /usr/bin/certbot 2>/dev/null
        fi
    else
        # 2. Fallback to apt for Debian or if snap is missing
        echo -e "${CYAN}Instalando Certbot vía APT...${NC}"
        apt-get update
        apt-get install -y certbot python3-certbot-apache
    fi

    # Verify installation
    if command -v certbot &> /dev/null; then
        VER=$(certbot --version 2>&1)
        LOC=$(which certbot)
        msg_box "Éxito" "Certbot ha sido instalado correctamente.\n\nVersión: $VER\nRuta: $LOC"
    else
        msg_box "Error de Instalación" "No se pudo encontrar el comando 'certbot' después de la instalación.\n\nIntenta ejecutar manualmente:\nsudo snap install --classic certbot"
        return 1
    fi
}

function add_ssl_to_existing() {
    msg_box "SSL para Dominio Existente" "Esta opción permite agregar un certificado SSL de Let's Encrypt a un dominio que ya haya sido configurado o ingresar uno manualmente."
    
    # List available configs, excluding defaults and ssl
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vx "000-default" | grep -vx "default-ssl")
    
    OPTIONS=("Manual" "Ingresar dominio manualmente")
    for site in $SITES; do
        OPTIONS+=("$site" "Configuración detectada")
    done
    
    DOMAIN_CHOICE=$(menu "Seleccionar Dominio" "Elige el dominio o selecciona 'Manual':" "${OPTIONS[@]}")
    
    [ -z "$DOMAIN_CHOICE" ] && return
    
    if [ "$DOMAIN_CHOICE" == "Manual" ]; then
        DOMAIN=$(input_box "Dominio Manual" "Ingresa el nombre del dominio (ej: ejemplo.com):" "")
        [ -z "$DOMAIN" ] && return
    else
        DOMAIN=$DOMAIN_CHOICE
    fi
    
    # Ask about www alias
    yes_no "Alias WWW" "¿Deseas incluir el alias 'www.$DOMAIN' en el certificado?"
    INCLUDE_WWW=$?
    
    if ! command -v certbot &> /dev/null; then
        install_certbot
    fi
    
    echo -e "${CYAN}Verificando resolución DNS para $DOMAIN...${NC}"
    if ! host "$DOMAIN" &> /dev/null; then
        msg_box "ADVERTENCIA CRÍTICA DNS" "¡ATENCIÓN!\nEl dominio '$DOMAIN' NO parece apuntar a ninguna IP.\n\nSi continúas, Certbot FALLARÁ y verás el error 'RX_RECORD_TOO_LONG' porque Apache no activará el modo seguro."
    fi

    if [ $INCLUDE_WWW -eq 0 ]; then
        echo -e "${CYAN}Verificando resolución DNS para www.$DOMAIN...${NC}"
        if ! host "www.$DOMAIN" &> /dev/null; then
             yes_no "DNS Fallido (www)" "El subdominio 'www.$DOMAIN' NO resuelve por DNS.\n\n¿Deseas SALTAR el alias 'www' para que el certificado principal se genere correctamente?\n(Recomendado: SI)"
             if [ $? -eq 0 ]; then
                  INCLUDE_WWW=1 # Force skip WWW
                  echo -e "${YELLOW}Saltando alias 'www' por falta de DNS.${NC}"
             else
                  msg_box "Aviso" "Intentaremos incluir 'www', pero si falla no tendrás HTTPS en ningún dominio."
             fi
        fi
    fi

    echo -e "${CYAN}Ejecutando Certbot para $DOMAIN...${NC}"
    if [ $INCLUDE_WWW -eq 0 ]; then
        certbot --apache -d "$DOMAIN" -d "www.$DOMAIN"
    else
        certbot --apache -d "$DOMAIN"
    fi
    
    if [ $? -eq 0 ]; then
        msg_box "SSL Exitoso" "Certificado SSL configurado correctamente para $DOMAIN."
    else
        msg_box "ERROR CERTBOT" "Hubo un problema al generar el certificado.\n\n1. Verifica que el dominio apunte a la IP del servidor.\n2. Asegúrate de que el puerto 80 esté abierto.\n3. Si intentaste incluir 'www' y falló, reintenta SIN 'www'."
    fi
}
function apply_permissions() {
    local OWNER=$1
    local VPATH=$2
    
    echo -e "${CYAN}Applying permissions for $OWNER on $VPATH...${NC}"
    chown -R "$OWNER:www-data" "$VPATH"
    find "$VPATH" -type d -exec chmod 2775 {} +
    find "$VPATH" -type f -exec chmod 0664 {} +
    
    if command -v setfacl &> /dev/null; then
        setfacl -R -m "u:$OWNER:rwx" "$VPATH"
        setfacl -R -d -m "u:$OWNER:rwx" "$VPATH"
        setfacl -R -m "g:www-data:rwx" "$VPATH"
        setfacl -R -d -m "g:www-data:rwx" "$VPATH"
    fi

    if [ "$OWNER" != "www-data" ] && [ "$OWNER" != "root" ]; then
        usermod -a -G www-data "$OWNER"
    fi
}

function add_domain() {
    msg_box "Nuevo Host Virtual" "Esta herramienta creará un nuevo archivo de configuración de Virtual Host. Podrás elegir entre un sitio local (físico en este server) o un Proxy (apuntar a otra IP)."
    
    # 1. Basic Info
    DOMAIN=$(input_box "Dominio" "Introduce el dominio (ej: ejemplo.com):" "ejemplo.com")
    [ -z "$DOMAIN" ] && return
    
    # 2. Alias WWW selection
    yes_no "Alias WWW" "¿Deseas incluir el alias 'www.$DOMAIN'? (Se recomienda No si no tienes el registro DNS creado)"
    WANT_WWW=$? # 0 = Yes, 1 = No
    
    SERVER_ALIAS=""
    if [ $WANT_WWW -eq 0 ]; then
        SERVER_ALIAS="ServerAlias www.$DOMAIN"
    fi

    # Check if domain already exists
    if [ -f "/etc/apache2/sites-available/$DOMAIN.conf" ]; then
        msg_box "Error" "El dominio $DOMAIN ya existe."
        return
    fi

    # Selection: Local vs Proxy
    VTYPE=$(whiptail --title "Tipo de VHost" --menu "Selecciona el tipo de Virtual Host para $DOMAIN:" 15 60 2 \
        "local" "Local (Archivos en esta PC + SFTP)" \
        "proxy" "Proxy (Redirigir a otra PC/IP/Puerto)" 3>&1 1>&2 2>&3)
    
    [ -z "$VTYPE" ] && return

    if [ "$VTYPE" == "local" ]; then
        VPATH=$(input_box "Ruta Web" "Introduce la ruta para la carpeta del sitio:" "/var/www/$DOMAIN")
        [ -z "$VPATH" ] && return
        
        # 2. User/Owner Selection
        NEW_USER_CHOICE=""
        OWNER=""
        yes_no "Nuevo Usuario" "¿Deseas crear un nuevo usuario dedicado para este dominio?"
        if [ $? -eq 0 ]; then
            NEW_USER_CHOICE="YES"
            # Generate username
            OWNER=$(echo "$DOMAIN" | cut -d'.' -f1 | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
            if id "$OWNER" &>/dev/null; then
                OWNER="${OWNER}_$(tr -dc '[:alnum:]' < /dev/urandom | head -c 4)"
            fi
            NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
        else
            USERS=$(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1 }' /etc/passwd)
            USER_OPTIONS=("root" "Root User (Admin)" "MANUAL" "Escribir usuario manualmente")
            for u in $USERS; do
                USER_OPTIONS+=("$u" "Usuario del Sistema")
            done
            USER_OPTIONS+=("www-data" "Web Server User")
            
            OWNER=$(menu "Seleccionar Dueño" "Elige el usuario que debe ser dueño de los archivos:" "${USER_OPTIONS[@]}")
            [ -z "$OWNER" ] && return
    
            if [ "$OWNER" == "MANUAL" ]; then
                OWNER=$(input_box "Usuario Manual" "Introduce el nombre del usuario exactamente:")
                [ -z "$OWNER" ] && return
            fi
        fi

        # 3. PHP Version Selection
        INSTALLED_PHP=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$')
        if [ -z "$INSTALLED_PHP" ]; then
            PHP_VH_VER="default"
        else
            PHP_OPTIONS=()
            for v in $INSTALLED_PHP; do
                PHP_OPTIONS+=("$v" "PHP-FPM version $v")
            done
            PHP_VH_VER=$(menu "Versión de PHP" "Selecciona la versión de PHP para este sitio:" "${PHP_OPTIONS[@]}")
            [ -z "$PHP_VH_VER" ] && PHP_VH_VER=$(echo $INSTALLED_PHP | awk '{print $1}')
        fi

        # 4. SSL Preference
        yes_no "SSL Certificado" "¿Deseas intentar instalar un certificado SSL con Certbot ahora?"
        WANT_SSL=$?

        # --- EXECUTION PHASE (LOCAL) ---
        echo -e "${CYAN}Creating directory $VPATH...${NC}"
        mkdir -p "$VPATH"
        
        if [ "$NEW_USER_CHOICE" == "YES" ]; then
            echo -e "${CYAN}Creando usuario $OWNER...${NC}"
            useradd -m -d "$VPATH" -s /usr/sbin/nologin -G www-data "$OWNER"
            echo "$OWNER:$NEW_PASS" | chpasswd
            
            CREDS_MSG="
--- CREDENCIALES PARA SFTP ---
Usuario: $OWNER
Password: $NEW_PASS
-----------------------------"
            echo -e "${GREEN}$CREDS_MSG${NC}"
        else
            CREDS_MSG=""
        fi

        apply_permissions "$OWNER" "$VPATH"
        
        if [ ! -f "$VPATH/index.html" ] && [ ! -f "$VPATH/index.php" ]; then
            echo "<h1>Welcome to $DOMAIN</h1>" > "$VPATH/index.html"
            chown "$OWNER:www-data" "$VPATH/index.html"
        fi
        
        PHP_FPM_CONF=""
        if [ "$PHP_VH_VER" != "default" ]; then
            PHP_FPM_CONF="
    <FilesMatch \.php$>
        SetHandler \"proxy:unix:/run/php/php$PHP_VH_VER-fpm.sock|fcgi://localhost\"
    </FilesMatch>"
        fi

        echo -e "${CYAN}Creando configuración de VirtualHost (Local)...${NC}"
        cat <<EOF > "/etc/apache2/sites-available/$DOMAIN.conf"
<VirtualHost *:80>
    ServerName $DOMAIN
    $SERVER_ALIAS
    DocumentRoot $VPATH
    
    <Directory $VPATH>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    $PHP_FPM_CONF

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

    else # --- PROXY TYPE ---
        TARGET_URL=$(input_box "URL de Destino" "Introduce la URL o IP a la que quieres apuntar (ej: http://1.2.3.4 o http://localhost:8080):")
        [ -z "$TARGET_URL" ] && return
        
        # 4. SSL Preference
        yes_no "SSL Certificado" "¿Deseas intentar instalar un certificado SSL con Certbot ahora?"
        WANT_SSL=$?

        # Ensure modules are enabled
        a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests &> /dev/null

        echo -e "${CYAN}Creando configuración de VirtualHost (Proxy)...${NC}"
        cat <<EOF > "/etc/apache2/sites-available/$DOMAIN.conf"
<VirtualHost *:80>
    ServerName $DOMAIN
    $SERVER_ALIAS

    ProxyPreserveHost On
    ProxyPass / $TARGET_URL/
    ProxyPassReverse / $TARGET_URL/

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-proxy-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-proxy-access.log combined
</VirtualHost>
EOF
        CREDS_MSG=""
    fi
    
    a2ensite "$DOMAIN.conf"
    systemctl reload apache2
    
    # 5. SSL Execution
    if [ $WANT_SSL -eq 0 ]; then
        if ! command -v certbot &> /dev/null; then
            install_certbot
        fi
        echo -e "${CYAN}Iniciando Certbot para $DOMAIN...${NC}"
        
        # SSL with optional WWW and DNS check
        if [ $WANT_WWW -eq 0 ] && host "www.$DOMAIN" &> /dev/null; then
             certbot --apache -d "$DOMAIN" -d "www.$DOMAIN"
        else
             [ $WANT_WWW -eq 0 ] && echo -e "${YELLOW}Advertencia: Saltando 'www' porque no resuelve por DNS.${NC}"
             certbot --apache -d "$DOMAIN"
        fi
    fi
    
    if [ -n "$CREDS_MSG" ]; then
        msg_box "CREDENCIALES OBTENIDAS" "$CREDS_MSG"
        echo -e "${GREEN}$CREDS_MSG${NC}"
    fi

    msg_box "Éxito" "Configuración completada para $DOMAIN ($VTYPE)."
}

function change_root() {
    msg_box "Cambiar DocumentRoot" "Esta opción permite cambiar la carpeta raíz (DocumentRoot) por defecto de Apache /var/www/html a cualquier otra ruta de tu elección."
    NEW_ROOT=$(input_box "Default DocumentRoot" "Enter the new path for the default website:" "/var/www/html")
    [ -z "$NEW_ROOT" ] && return
    
    mkdir -p "$NEW_ROOT"
    
    echo -e "${CYAN}Updating 000-default.conf...${NC}"
    sed -i "s|DocumentRoot .*|DocumentRoot $NEW_ROOT|g" /etc/apache2/sites-available/000-default.conf
    
    # Also update the directory permissions in apache2.conf if it's outside /var/www
    if [[ "$NEW_ROOT" != /var/www/* ]]; then
        yes_no "External Directory" "The path is outside /var/www. Do you want to add Global permissions in apache2.conf?"
        if [ $? -eq 0 ]; then
             cat >> /etc/apache2/apache2.conf <<EOF

<Directory $NEW_ROOT>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
        fi
    fi
    
    systemctl restart apache2
    msg_box "Success" "Default DocumentRoot changed to $NEW_ROOT"
}

function list_vhosts() {
    msg_box "Lista de VHosts" "Aquí puedes ver todos los dominios configurados en este servidor, verificar su estado y habilitarlos o deshabilitarlos según necesites."
    echo -e "${CYAN}Retrieving list of Virtual Hosts...${NC}"
    # Get enabled sites
    ENABLED_SITES=$(ls /etc/apache2/sites-enabled/ | grep ".conf$" | sed 's/.conf$//')
    # Get available but not enabled sites
    AVAILABLE_SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vx "000-default" | grep -vx "default-ssl")
    
    MENU_ITEMS=""
    for site in $ENABLED_SITES; do
        ROOT_PATH=$(grep "DocumentRoot" /etc/apache2/sites-enabled/$site.conf | awk '{print $2}')
        MENU_ITEMS="$MENU_ITEMS $site [ENABLED]($ROOT_PATH)"
    done
    for site in $AVAILABLE_SITES; do
        # Check if it's already in the enabled list
        if [[ ! "$ENABLED_SITES" =~ "$site" ]]; then
            ROOT_PATH=$(grep "DocumentRoot" /etc/apache2/sites-available/$site.conf | awk '{print $2}')
            MENU_ITEMS="$MENU_ITEMS $site [AVAILABLE]($ROOT_PATH)"
        fi
    done

    if [ -z "$MENU_ITEMS" ]; then
        msg_box "Info" "No Virtual Hosts found (besides defaults)."
        return
    fi

    SELECTED_SITE=$(menu "Virtual Hosts List" "Manage your sites (Name [Status](Path)):" $MENU_ITEMS "Back" "Return to main menu")
    
    [ -z "$SELECTED_SITE" ] || [ "$SELECTED_SITE" == "Back" ] && return
    
    # Simple action menu for selection
    ACTION=$(menu "Manage: $SELECTED_SITE" "What do you want to do with this site?" \
        "1" "Check status (Apache status)" \
        "2" "Open configuration file" \
        "3" "Disable site (a2dissite)" \
        "4" "Enable site (a2ensite)" \
        "5" "ELIMINAR por completo (Borrar archivos/conf)")

    case $ACTION in
        1) systemctl status apache2 | head -n 20 && read -p "Press enter to return" ;;
        2) nano "/etc/apache2/sites-available/$SELECTED_SITE.conf" ;;
        3) a2dissite "$SELECTED_SITE" && systemctl restart apache2 && msg_box "Success" "Site disabled." ;;
        4) a2ensite "$SELECTED_SITE" && systemctl restart apache2 && msg_box "Success" "Site enabled." ;;
        5) delete_domain "$SELECTED_SITE" ;;
    esac
}

function install_custom_extension() {
    msg_box "Extensión Personalizada" "Si la extensión que buscas no está en la lista, puedes escribir su nombre aquí. El script intentará buscarla e instalarla usando los repositorios de tu sistema."
    EXT_NAME=$(input_box "Custom PHP Extension" "Enter the name of the PHP extension to install (e.g., redis, imagick):")
    [ -z "$EXT_NAME" ] && return
    
    # Detect installed PHP versions
    INSTALLED_PHP=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$')
    if [ -z "$INSTALLED_PHP" ]; then
        PHP_VERS_LIST=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    else
        PHP_OPTIONS=("TODAS" "Todas las versiones instaladas")
        for v in $INSTALLED_PHP; do
            PHP_OPTIONS+=("$v" "PHP version $v")
        done
        PHP_VERS_CHOICE=$(menu "Seleccionar PHP" "Elige en qué versión quieres instalar '$EXT_NAME':" "${PHP_OPTIONS[@]}")
        [ -z "$PHP_VERS_CHOICE" ] && return
        
        if [ "$PHP_VERS_CHOICE" == "TODAS" ]; then
            PHP_VERS_LIST=$INSTALLED_PHP
        else
            PHP_VERS_LIST=$PHP_VERS_CHOICE
        fi
    fi

    for pver in $PHP_VERS_LIST; do
        echo -e "${CYAN}Installing php$pver-$EXT_NAME...${NC}"
        apt-get install -y "php$pver-$EXT_NAME"
        systemctl restart "php$pver-fpm" 2>/dev/null
    done
    
    systemctl restart apache2
    msg_box "Success" "The extension '$EXT_NAME' has been installed."
}

function fix_permissions() {
    msg_box "Reparar Permisos (SFTP/SSH)" "Esta herramienta ajustará el dueño y los permisos de un sitio para que puedas editar archivos vía SFTP/SSH sin problemas."
    
    # List available configs
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vpx "000-default" | grep -vpx "default-ssl")
    
    OPTIONS=("GLOBAL" "Toda la carpeta /var/www (Acceso total)")
    for site in $SITES; do
        OPTIONS+=("$site" "Configuración detectada")
    done
    
    DOMAIN=$(menu "Seleccionar Dominio o Global" "Elige el dominio o selecciona GLOBAL para toda la carpeta /var/www:" "${OPTIONS[@]}")
    [ -z "$DOMAIN" ] && return
    
    if [ "$DOMAIN" == "GLOBAL" ]; then
        VPATH="/var/www"
    else
        # Identify DocumentRoot
        VPATH=$(grep "DocumentRoot" "/etc/apache2/sites-available/$DOMAIN.conf" | awk '{print $2}' | head -n 1)
    fi
    
    if [ -z "$VPATH" ] || [ ! -d "$VPATH" ]; then
        msg_box "Error" "No se pudo encontrar la carpeta del sitio o no existe."
        return
    fi
    
    # Ensure ACL package is installed if possible
    if ! command -v setfacl &> /dev/null; then
        echo -e "${YELLOW}Installing ACL support for better permissions...${NC}"
        apt-get update && apt-get install -y acl
    fi

    # User selection
    USERS=$(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1 }' /etc/passwd)
    USER_OPTIONS=("root" "Root User (Admin)" "NEW" "CREAR NUEVO USUARIO" "MANUAL" "Escribir usuario manualmente")
    for u in $USERS; do
        USER_OPTIONS+=("$u" "Usuario del Sistema")
    done
    USER_OPTIONS+=("www-data" "Web Server User")
    
    OWNER=$(menu "Seleccionar Dueño" "Elige el usuario que debe tener permisos totales (ej: tu usuario de login):" "${USER_OPTIONS[@]}")
    [ -z "$OWNER" ] && return

    CREDS_MSG=""
    if [ "$OWNER" == "NEW" ]; then
        SUGGESTED_USER=$(echo "$DOMAIN" | cut -d'.' -f1 | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
        if [ "$DOMAIN" == "GLOBAL" ]; then SUGGESTED_USER="www_admin"; fi
        
        NEW_USER=$(input_box "Nuevo Usuario" "Introduce el nombre del nuevo usuario:" "$SUGGESTED_USER")
        [ -z "$NEW_USER" ] && return
        
        NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
        
        echo -e "${CYAN}Creando usuario $NEW_USER...${NC}"
        useradd -m -d "$VPATH" -s /usr/sbin/nologin -G www-data "$NEW_USER"
        echo "$NEW_USER:$NEW_PASS" | chpasswd
        OWNER="$NEW_USER"
        CREDS_MSG="
--- CREDENCIALES PARA SFTP ---
Usuario: $NEW_USER
Password: $NEW_PASS
-----------------------------"
        echo -e "${GREEN}$CREDS_MSG${NC}"
    elif [ "$OWNER" == "MANUAL" ]; then
        OWNER=$(input_box "Usuario Manual" "Introduce el nombre del usuario exactamente:")
        [ -z "$OWNER" ] && return
    fi
    
    apply_permissions "$OWNER" "$VPATH"
    
    # Diagnostics
    DIAG=$(ls -ld "$VPATH")
    USER_INFO=$(id "$OWNER")

    if [ "$OWNER" != "www-data" ]; then
        usermod -a -G www-data "$OWNER"
    fi

    # Diagnostics
    if [ -n "$CREDS_MSG" ]; then
        msg_box "CREDENCIALES OBTENIDAS" "$CREDS_MSG"
        echo -e "${GREEN}$CREDS_MSG${NC}"
    fi

    msg_box "Reparación Completa" "Permisos reparados para $DOMAIN.\n\nDIAGNÓSTICO:\nCarpeta: $DIAG\nInfo Usuario: $USER_INFO\n\nRECUERDA: Cierra y vuelve a abrir tu sesión SFTP/SSH para aplicar cambios."
}

function manage_users() {
    while true; do
        UCHOICE=$(whiptail --title "Gestión de Usuarios" --menu "Selecciona una acción:" 15 60 4 \
            "1" "Crear Nuevo Usuario (SFTP)" \
            "2" "Eliminar Usuario" \
            "3" "Cambiar Contraseña" \
            "4" "Atrás" 3>&1 1>&2 2>&3)
        
        [ -z "$UCHOICE" ] || [ "$UCHOICE" == "4" ] && break
        
        case $UCHOICE in
            1)
                USERNAME=$(input_box "Nuevo Usuario" "Introduce el nombre del usuario (letras y números):")
                [ -z "$USERNAME" ] && continue
                
                if id "$USERNAME" &>/dev/null; then
                    msg_box "Error" "El usuario ya existe."
                    continue
                fi
                
                HDIR=$(input_box "Directorio Home" "Introduce la carpeta raíz para este usuario (ej: /var/www/dominio):" "/var/www/$USERNAME")
                [ -z "$HDIR" ] && continue
                mkdir -p "$HDIR"
                
                yes_no "Contraseña" "¿Deseas generar una contraseña aleatoria?"
                if [ $? -eq 0 ]; then
                    PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
                else
                    PASSWORD=$(input_box "Contraseña" "Introduce la contraseña:")
                fi
                [ -z "$PASSWORD" ] && continue
                
                useradd -m -d "$HDIR" -s /usr/sbin/nologin -G www-data "$USERNAME"
                echo "$USERNAME:$PASSWORD" | chpasswd
                apply_permissions "$USERNAME" "$HDIR"
                
                msg_box "Usuario Creado" "Usuario: $USERNAME\nPassword: $PASSWORD\nDirectorio: $HDIR"
                echo -e "${GREEN}Usuario: $USERNAME | Password: $PASSWORD | Directorio: $HDIR${NC}"
                ;;
                
            2)
                # List non-system users
                USERS=$(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1 }' /etc/passwd)
                U_OPTIONS=()
                for u in $USERS; do
                    U_OPTIONS+=("$u" "Usuario del Sistema")
                done
                
                DEL_USER=$(menu "Eliminar Usuario" "Selecciona el usuario que deseas borrar:" "${U_OPTIONS[@]}")
                [ -z "$DEL_USER" ] && continue
                
                yes_no "Confirmar" "¿Estás seguro de que quieres eliminar a $DEL_USER? Los archivos NO se borrarán."
                if [ $? -eq 0 ]; then
                    userdel "$DEL_USER"
                    msg_box "Éxito" "Usuario $DEL_USER eliminado."
                fi
                ;;
                
            3)
                USERS=$(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1 }' /etc/passwd)
                U_OPTIONS=()
                for u in $USERS; do
                    U_OPTIONS+=("$u" "Usuario del Sistema")
                done
                
                P_USER=$(menu "Cambiar Password" "Selecciona el usuario:" "${U_OPTIONS[@]}")
                [ -z "$P_USER" ] && continue
                
                NEW_P=$(input_box "Nueva Contraseña" "Introduce la nueva contraseña para $P_USER:")
                [ -z "$NEW_P" ] && continue
                
                echo "$P_USER:$NEW_P" | chpasswd
                msg_box "Éxito" "Contraseña actualizada para $P_USER."
                ;;
        esac
    done
}

function install_sqlsrv() {
    msg_box "Instalación de Drivers MSSQL & dblib" "Esta opción instalará los drivers de Microsoft para SQL Server y las extensiones 'sqlsrv', 'pdo_sqlsrv' y 'pdo_dblib'.\n\nHemos añadido la opción de seleccionar versiones múltiples para asegurar la compatibilidad con WebEngine y otros CMS."
    
    # 1. Version Selection
    PHP_VERSIONS=$(whiptail --title "Versiones de PHP" --checklist "Selecciona las versiones de PHP para los drivers MSSQL:" 15 60 4 \
        "8.1" "PHP 8.1" ON \
        "8.2" "PHP 8.2" ON \
        "8.3" "PHP 8.3" ON \
        "8.4" "PHP 8.4" ON 3>&1 1>&2 2>&3)
    
    [ -z "$PHP_VERSIONS" ] && return
    PHP_VERSIONS=$(echo $PHP_VERSIONS | sed 's/"//g')

    echo -e "${CYAN}Adding Microsoft Repository...${NC}"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
    curl -fsSL https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list > /etc/apt/sources.list.d/mssql-release.list
    
    apt-get update
    echo -e "${CYAN}Installing MS ODBC Drivers...${NC}"
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev
    
    for v in $PHP_VERSIONS; do
        echo -e "${CYAN}Procesando PHP $v...${NC}"
        
        # Check if PHP version is installed
        if [ ! -d "/etc/php/$v" ]; then
            yes_no "Instalar PHP $v" "La versión PHP $v no parece estar instalada. ¿Deseas instalarla ahora?"
            if [ $? -eq 0 ]; then
                apt-get install -y "php$v-fpm" "php$v-cli" "php$v-common"
                a2enmod proxy_fcgi setenvif
                a2enconf "php$v-fpm"
            else
                echo -e "${YELLOW}Saltando PHP $v...${NC}"
                continue
            fi
        fi

        echo -e "${CYAN}Instalando extensiones PHP $v para MSSQL (sqlsrv & dblib)...${NC}"
        apt-get install -y "php$v-sqlsrv" "php$v-sybase" 2>/dev/null
        
        # Fallback if apt fails (PECL method)
        if [ $? -ne 0 ]; then
             echo -e "${YELLOW}Apt failed for php$v-sqlsrv, trying PECL...${NC}"
             apt-get install -y "php$v-dev" "php$v-xml" php-pear
             printf "\n" | pecl install sqlsrv
             printf "\n" | pecl install pdo_sqlsrv
             
             # Create ini files if pecl doesn't
             echo "extension=sqlsrv.so" > "/etc/php/$v/mods-available/sqlsrv.ini"
             echo "extension=pdo_sqlsrv.so" > "/etc/php/$v/mods-available/pdo_sqlsrv.ini"
        fi
        
        # Ensure all are enabled
        phpenmod -v "$v" pdo_dblib sqlsrv pdo_sqlsrv 2>/dev/null
        
        # Restart FPM for this version
        systemctl restart "php$v-fpm" 2>/dev/null
    done
    
    systemctl restart apache2
    
    # Verify drivers visually
    echo -e "${GREEN}Resumen de Drivers (PHP Default):${NC}"
    php -m | grep -E "sqlsrv|dblib"
    msg_box "Éxito" "Drivers de MSSQL y dblib instalados en las versiones seleccionadas."
}

function get_mysql_host() {
    HCHOICE=$(whiptail --title "Host MySQL" --menu "Selecciona el origen permitido para el usuario:" 15 60 3 \
        "%" "Cualquier Host (Público/Remoto)" \
        "localhost" "Local solamente" \
        "custom" "IP Específica..." 3>&1 1>&2 2>&3)
    
    if [ "$HCHOICE" == "custom" ]; then
        MHOST=$(input_box "IP MySQL" "Introduce la IP permitida:")
        [ -z "$MHOST" ] && echo "localhost" || echo "$MHOST"
    else
        echo "$HCHOICE"
    fi
}

function manage_mysql() {
    # Check if mysql is installed
    if ! command -v mysql &> /dev/null; then
        yes_no "Instalar MySQL" "MySQL Server no parece estar instalado. ¿Deseas instalarlo ahora?"
        if [ $? -eq 0 ]; then
            echo -e "${CYAN}Instalando MySQL Server...${NC}"
            apt-get update
            apt-get install -y mysql-server
            systemctl start mysql
            systemctl enable mysql
            
            # Install php-mysql for all versions
            INSTALLED_PHP=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$')
            for v in $INSTALLED_PHP; do
                apt-get install -y "php$v-mysql"
                systemctl restart "php$v-fpm" 2>/dev/null
            done
            msg_box "Exito" "MySQL Server ha sido instalado y configurado para PHP."
        fi
    fi

    while true; do
        MCHOICE=$(whiptail --title "Gestión de MySQL" --menu "Selecciona una opción:" 18 65 6 \
            "1" "Crear Base de Datos" \
            "2" "Eliminar Base de Datos" \
            "3" "Crear Usuario y Password" \
            "4" "Eliminar Usuario" \
            "5" "Asignar Permisos (Grant All)" \
            "6" "Atrás" 3>&1 1>&2 2>&3)
        
        [ -z "$MCHOICE" ] || [ "$MCHOICE" == "6" ] && break
        
        case $MCHOICE in
            1)
                DBNAME=$(input_box "Nueva DB" "Introduce el nombre de la base de datos:")
                [ -n "$DBNAME" ] && mysql -e "CREATE DATABASE IF NOT EXISTS \`$DBNAME\`;" && msg_box "Exito" "Base de datos '$DBNAME' creada."
                ;;
            2)
                DBS=$(mysql -N -s -e "SHOW DATABASES;" | grep -Ev "information_schema|performance_schema|mysql|sys")
                DB_OPTIONS=()
                for db in $DBS; do DB_OPTIONS+=("$db" "Base de Datos"); done
                DEL_DB=$(menu "Eliminar DB" "Selecciona la base de datos a borrar PERMANENTEMENTE:" "${DB_OPTIONS[@]}")
                [ -n "$DEL_DB" ] && yes_no "Confirmar" "¿Seguro que quieres borrar la DB $DEL_DB?" && [ $? -eq 0 ] && mysql -e "DROP DATABASE \`$DEL_DB\`;" && msg_box "Exito" "Base de datos '$DEL_DB' eliminada."
                ;;
            3)
                MUSER=$(input_box "Nuevo Usuario" "Introduce el nombre del usuario MySQL:")
                [ -z "$MUSER" ] && continue
                
                MHOST=$(get_mysql_host)
                [ -z "$MHOST" ] && continue
                
                yes_no "Password" "¿Generar contraseña aleatoria?"
                if [ $? -eq 0 ]; then
                    MPASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
                else
                    MPASS=$(input_box "Password" "Introduce la contraseña:")
                fi
                [ -z "$MPASS" ] && continue
                
                mysql -e "CREATE USER '$MUSER'@'$MHOST' IDENTIFIED BY '$MPASS';"
                msg_box "Usuario Creado" "Usuario: $MUSER\nPassword: $MPASS\nHost: $MHOST"
                echo -e "${GREEN}MySQL User: $MUSER | Pass: $MPASS | Host: $MHOST${NC}"
                ;;
            4)
                # List users as User@Host
                MUSERS=$(mysql -N -s -e "SELECT CONCAT(User, '@', Host) FROM mysql.user;" | grep -Ev "root|mysql.sys|mysql.session|debian-sys-maint")
                U_OPTIONS=()
                for u in $MUSERS; do U_OPTIONS+=("$u" "Usuario MySQL"); done
                DEL_U_HOST=$(menu "Eliminar Usuario" "Selecciona el usuario a borrar:" "${U_OPTIONS[@]}")
                [ -z "$DEL_U_HOST" ] && continue
                
                # Split user and host
                U_ONLY=$(echo $DEL_U_HOST | cut -d'@' -f1)
                H_ONLY=$(echo $DEL_U_HOST | cut -d'@' -f2)
                
                yes_no "Confirmar" "¿Borrar usuario '$U_ONLY' con host '$H_ONLY'?" && [ $? -eq 0 ] && mysql -e "DROP USER '$U_ONLY'@'$H_ONLY';" && msg_box "Exito" "Usuario '$DEL_U_HOST' eliminado."
                ;;
            5)
                # Select User
                MUSERS=$(mysql -N -s -e "SELECT CONCAT(User, '@', Host) FROM mysql.user;" | grep -Ev "root|mysql.sys|mysql.session|debian-sys-maint")
                U_OPTIONS=()
                for u in $MUSERS; do U_OPTIONS+=("$u" "Usuario MySQL"); done
                GUSER_HOST=$(menu "Seleccionar Usuario" "Elige el usuario:" "${U_OPTIONS[@]}")
                [ -z "$GUSER_HOST" ] && continue
                
                # Split user and host
                U_ONLY=$(echo $GUSER_HOST | cut -d'@' -f1)
                H_ONLY=$(echo $GUSER_HOST | cut -d'@' -f2)

                # Select DB
                DBS=$(mysql -N -s -e "SHOW DATABASES;" | grep -Ev "information_schema|performance_schema|mysql|sys")
                DB_OPTIONS=()
                for db in $DBS; do DB_OPTIONS+=("$db" "Base de Datos"); done
                GDB=$(menu "Seleccionar DB" "Elige la base de datos para darle permisos totales:" "${DB_OPTIONS[@]}")
                [ -z "$GDB" ] && continue
                
                mysql -e "GRANT ALL PRIVILEGES ON \`$GDB\`.* TO '$U_ONLY'@'$H_ONLY'; FLUSH PRIVILEGES;"
                ;;
        esac
    done
}

function change_vhost_php() {
    msg_box "Cambiar Versión de PHP" "Esta herramienta te permite cambiar la versión de PHP (FPM) que utiliza un host virtual existente."
    
    # 1. List VHosts
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vx "000-default" | grep -vx "default-ssl")
    if [ -z "$SITES" ]; then
        msg_box "Error" "No se encontraron Virtual Hosts personalizados."
        return
    fi
    
    OPTIONS=()
    for site in $SITES; do
        OPTIONS+=("$site" "Configuración de Apache")
    done
    DOMAIN=$(menu "Seleccionar Dominio" "Elige el dominio que deseas modificar:" "${OPTIONS[@]}")
    [ -z "$DOMAIN" ] && return
    
    CONF_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
    
    # 2. List Installed PHP Versions
    INSTALLED_PHP=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$')
    PHP_OPTS=("default" "Usar versión por defecto del sistema")
    for v in $INSTALLED_PHP; do
        PHP_OPTS+=("$v" "PHP version $v")
    done
    NEW_VER=$(menu "Nueva Versión de PHP" "Selecciona la nueva versión para $DOMAIN:" "${PHP_OPTS[@]}")
    [ -z "$NEW_VER" ] && return
    
    # 3. Update Configuration
    echo -e "${CYAN}Actualizando configuración para $DOMAIN...${NC}"
    
    # Remove existing PHP handler blocks
    sed -i '/<FilesMatch \\.php$>/,/<\/FilesMatch>/d' "$CONF_FILE"
    
    if [ "$NEW_VER" != "default" ]; then
        # Insert new handler block before the closing </VirtualHost>
        # We look for the last line and insert before it
        PHP_BLOCK="    <FilesMatch \\.php$>\n        SetHandler \"proxy:unix:/run/php/php$NEW_VER-fpm.sock|fcgi://localhost\"\n    </FilesMatch>"
        sed -i "$ i $PHP_BLOCK" "$CONF_FILE"
    fi
    
    systemctl restart apache2
    msg_box "Éxito" "La versión de PHP para $DOMAIN ha sido actualizada a: $NEW_VER"
}

function diagnose_ssl() {
    msg_box "Diagnóstico SSL (Repair RX_RECORD_TOO_LONG)" "Esta herramienta buscará problemas comunes que causan errores de SSL. El error RX_RECORD_TOO_LONG indica usualmente que el servidor responde con HTTP plano en el puerto 443 (HTTPS)."
    
    # 1. Module check
    echo -e "${CYAN}Verificando módulos de Apache...${NC}"
    if ! apache2ctl -M | grep -qi "ssl"; then
        yes_no "Módulo SSL" "El módulo 'ssl' no está activo. Es indispensable para HTTPS. ¿Deseas activarlo ahora?"
        if [ $? -eq 0 ]; then
            echo -e "${CYAN}Activando mod_ssl...${NC}"
            a2enmod ssl
            systemctl restart apache2
        fi
    fi

    # 2. Port check (Listen 443)
    if ! grep -q "Listen 443" /etc/apache2/ports.conf; then
        yes_no "Puerto 443" "No se detectó 'Listen 443' en /etc/apache2/ports.conf. Esto impide que Apache escuche peticiones HTTPS. ¿Añadirlo ahora?"
        if [ $? -eq 0 ]; then
             echo "Listen 443" >> /etc/apache2/ports.conf
             echo -e "${GREEN}Añadido 'Listen 443' a ports.conf${NC}"
             systemctl restart apache2
        fi
    fi

    # 3. Domain check
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vx "000-default" | grep -vx "default-ssl")
    if [ -z "$SITES" ]; then
        msg_box "Error" "No se encontraron Virtual Hosts para diagnosticar."
        return
    fi
    
    DOMAIN=$(menu "Seleccionar Dominio" "Elige el dominio que tiene el problema para analizar su configuración:" $SITES)
    [ -z "$DOMAIN" ] && return
    
    # Search for SSL config file
    SSL_FILE=""
    if [ -f "/etc/apache2/sites-available/$DOMAIN-le-ssl.conf" ]; then
        SSL_FILE="/etc/apache2/sites-available/$DOMAIN-le-ssl.conf"
    elif [ -f "/etc/apache2/sites-available/$DOMAIN.ssl.conf" ]; then
        SSL_FILE="/etc/apache2/sites-available/$DOMAIN.ssl.conf"
    elif [ -f "/etc/apache2/sites-available/$DOMAIN.conf" ]; then
        if grep -q "<VirtualHost .*:443>" "/etc/apache2/sites-available/$DOMAIN.conf"; then
            SSL_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
        fi
    fi

    if [ -z "$SSL_FILE" ]; then
        msg_box "SSL No Detectado" "No se encontró una configuración SSL (puerto 443) para $DOMAIN.\nSe recomienda usar la opción 7 para configurar SSL con Certbot primero."
        return
    fi

    # 4. Check for SSLEngine on
    if grep -q "<VirtualHost .*:443>" "$SSL_FILE"; then
        if ! grep -qi "SSLEngine on" "$SSL_FILE"; then
            msg_box "ERROR DETECTADO" "El bloque de puerto 443 en $SSL_FILE existe pero NO tiene 'SSLEngine on'. Esto GARANTIZA el error RX_RECORD_TOO_LONG.\n\nIntentando reparación automática..."
            # Insert after the VirtualHost opening line (supporting various formats)
            sed -i '/<VirtualHost .*:443>/a \    SSLEngine on' "$SSL_FILE"
            systemctl reload apache2
            msg_box "Reparación Completada" "Se ha insertado 'SSLEngine on' en $SSL_FILE y recargado Apache."
        else
            msg_box "Verificación" "Se detectó 'SSLEngine on' en la configuración de $DOMAIN. Si el error persiste, podría ser un conflicto con el puerto 80 o el certificado no es válido."
        fi
    else
        msg_box "Aviso" "El archivo de configuración detectado no parece tener un bloque <VirtualHost *:443>."
    fi

    # 5. Check for 000-default.conf interference
    if [ -f "/etc/apache2/sites-enabled/000-default.conf" ]; then
        if grep -q "<VirtualHost .*:443>" "/etc/apache2/sites-enabled/000-default.conf"; then
             msg_box "CONFLITO DETECTADO" "Se detectó un bloque 443 en 000-default.conf que podría estar 'robando' el tráfico SSL de tu dominio.\n\nSe recomienda deshabilitar 000-default con: a2dissite 000-default"
        fi
    fi

    # 5.1 Check for default-ssl.conf interference
    if [ -f "/etc/apache2/sites-enabled/default-ssl.conf" ]; then
         msg_box "Aviso: default-ssl activo" "Se detectó 'default-ssl.conf' habilitado. Si este archivo no tiene la configuración correcta para tu dominio, podría causar problemas de handshake.\nPrueba deshabilitarlo con: a2dissite default-ssl"
    fi

    # 6. Check for ModSecurity
    if apache2ctl -M | grep -qi "security2"; then
        msg_box "ModSecurity Detectado" "Se detectó 'mod_security2' activo. Este módulo puede bloquear peticiones que parezcan sospechosas o interferir con Certbot.\n\nSi sigues con errores, prueba desactivarlo temporalmente:\nsudo a2dismod security2 && sudo systemctl restart apache2"
    fi

    # 7. Cloudflare Hint
    msg_box "Consejo Cloudflare" "Si usas Cloudflare, asegúrate de que el modo SSL en su panel esté en 'Full' o 'Full (Strict)'.\nSi está en 'Flexible', Cloudflare intentará entrar por el puerto 80 aunque el usuario pida HTTPS, lo que a veces causa bucles o errores."
    
    msg_box "Fin del Diagnóstico" "Verificación terminada. Si el error persiste:\n1. Revisa los logs: tail -n 20 /var/log/apache2/error.log\n2. Asegúrate de que no haya firewalls bloqueando el puerto 443."
}

function install_webengine() {
    msg_box "Instalador WebEngine CMS" "Esta opción descargará e instalará WebEngine CMS en el dominio que selecciones.\nRequisitos: PHP 8.1+ (8.4 recomendado), mod_rewrite y SQL Server support (sqlsrv)."
    
    # 1. Select Domain
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vx "000-default" | grep -vx "default-ssl")
    if [ -z "$SITES" ]; then
        msg_box "Error" "No se encontraron Virtual Hosts. Crea uno primero (Opción 6)."
        return
    fi
    
    DOMAIN=$(menu "Seleccionar Dominio" "Elige el dominio donde instalar WebEngine CMS:" $SITES)
    [ -z "$DOMAIN" ] && return
    
    # 2. Get DocumentRoot
    VPATH=$(grep "DocumentRoot" "/etc/apache2/sites-available/$DOMAIN.conf" | awk '{print $2}' | head -n 1)
    if [ -z "$VPATH" ] || [ ! -d "$VPATH" ]; then
        msg_box "Error" "No se pudo determinar la ruta del dominio o la carpeta no existe."
        return
    fi
    
    yes_no "Confirmar Instalación" "¿Deseas instalar WebEngine CMS en $VPATH?\nADVERTENCIA: Si la carpeta no está vacía, podrían haber archivos en conflicto."
    [ $? -ne 0 ] && return
    
    # 3. Prerequisites
    echo -e "${CYAN}Asegurando requisitos previos (PHP 8.4, SqlSrv, CMS Essentials)...${NC}"
    # Ensure PHP 8.4 and necessary modules
    apt-get update && apt-get install -y php8.4 php8.4-fpm php8.4-curl php8.4-gd php8.4-mbstring php8.4-xml php8.4-zip
    
    # Call existing helper for CMS modules and SQLSRV
    install_cms_essentials &>/dev/null
    install_sqlsrv &>/dev/null
    
    if ! command -v git &> /dev/null; then
        echo -e "${CYAN}Instalando Git...${NC}"
        apt-get update && apt-get install -y git
    fi
    
    # 4. Cloning
    echo -e "${CYAN}Clonando WebEngine CMS en $VPATH...${NC}"
    TEMP_CLONE="/tmp/webengine_clone_$(date +%s)"
    git clone https://github.com/lautaroangelico/WebEngine.git "$TEMP_CLONE"
    
    if [ $? -eq 0 ]; then
        # Copy to domain folder
        cp -r "$TEMP_CLONE"/. "$VPATH"/
        rm -rf "$TEMP_CLONE"
        
        # 5. Permissions
        OWNER=$(ls -ld "$VPATH" | awk '{print $3}')
        apply_permissions "$OWNER" "$VPATH"
        
        msg_box "Éxito" "WebEngine CMS ha sido descargado en $VPATH.\n\nPRÓXIMOS PASOS:\n1. Visita http://$DOMAIN/install en tu navegador.\n2. Configura el Cron Job: /includes/cron/cron.php (Cada minuto)."
    else
        msg_box "Error" "Hubo un problema al clonar el repositorio de GitHub."
    fi
}

function delete_domain() {
    local DOMAIN=$1
    
    if [ -z "$DOMAIN" ]; then
        msg_box "Eliminar Virtual Host" "CUIDADO: Esta opción eliminará la configuración del dominio y, si lo deseas, también todos sus archivos."
        
        # List available configs, excluding current defaults
        SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vx "000-default" | grep -vx "default-ssl")
        
        if [ -z "$SITES" ]; then
            msg_box "Info" "No se encontraron Virtual Hosts personalizados para eliminar."
            return
        fi
        
        OPTIONS=()
        for site in $SITES; do
            OPTIONS+=("$site" "Configuración de Apache")
        done
        
        DOMAIN=$(menu "Seleccionar Dominio para ELIMINAR" "Elige el dominio que deseas borrar permanentemente:" "${OPTIONS[@]}")
        
        [ -z "$DOMAIN" ] && return
    fi
    
    yes_no "Confirmar Eliminación" "¿Estás SEGURO de que deseas eliminar la configuración de $DOMAIN? Esta acción no se puede deshacer."
    [ $? -ne 0 ] && return
    
    # Identify DocumentRoot before deleting config
    VPATH=$(grep "DocumentRoot" "/etc/apache2/sites-available/$DOMAIN.conf" | awk '{print $2}' | head -n 1)
    
    echo -e "${RED}Disabling and removing configuration...${NC}"
    a2dissite "$DOMAIN" &> /dev/null
    rm "/etc/apache2/sites-available/$DOMAIN.conf"
    
    # Optional directory deletion
    if [ -n "$VPATH" ] && [ -d "$VPATH" ]; then
        yes_no "Eliminar Archivos" "¿Deseas eliminar también la carpeta del sitio y todo su contenido?\nRuta: $VPATH"
        if [ $? -eq 0 ]; then
            echo -e "${RED}Removing directory $VPATH...${NC}"
            rm -rf "$VPATH"
        fi
    fi
    
    systemctl restart apache2
    msg_box "Éxito" "El Virtual Host $DOMAIN ha sido eliminado correctamente."
}

function install_cms_essentials() {
    msg_box "Esenciales para CMS" "Esta opción instalará y activará los módulos necesarios para WebEngine, FusionCMS y otros: mod_rewrite, mod_security2, mod_headers, mod_expires, mod_deflate y mod_unique_id."
    
    echo -e "${CYAN}Instalando dependencias de ModSecurity...${NC}"
    apt-get update && apt-get install -y libapache2-mod-security2
    
    echo -e "${CYAN}Activando módulos esenciales...${NC}"
    # unique_id is required by security2
    a2enmod rewrite ssl headers expires deflate unique_id security2
    
    # Configure ModSecurity (Enable by default if first time)
    if [ -f "/etc/modsecurity/modsecurity.conf-recommended" ] && [ ! -f "/etc/modsecurity/modsecurity.conf" ]; then
        echo -e "${CYAN}Configurando ModSecurity básico...${NC}"
        cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
        sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
    fi
    
    systemctl restart apache2
    msg_box "Éxito" "Módulos esenciales instalados y activados correctamente.\n\nSe activó:\n- mod_security2 (WAF)\n- mod_rewrite (Friendly URLs)\n- mod_headers (Security)\n- mod_expires/deflate (Performance)\n- mod_unique_id"
}

# ==============================================================================
# Main Execution Loop
# ==============================================================================

function main_menu() {
    while true; do
        CHOICE=$(menu "Main Menu" "Select an option to manage your Apache server:" \
            "1" "Install Apache & PHP (Core)" \
            "2" "Install PHP Extensions (List)" \
            "3" "Install Custom PHP Extension" \
            "4" "Install Apache Modules" \
            "5" "Install Certbot (SSL)" \
            "6" "Add New Virtual Host" \
            "7" "Add SSL to Existing Domain" \
            "8" "List/Manage Virtual Hosts" \
            "9" "Delete Virtual Host" \
            "10" "Reparar Permisos (Fix Permissions)" \
            "11" "Gestión de Usuarios (Añadir/Borrar/Contraseña)" \
            "12" "Gestión de MySQL (Instalar/DB/Usuarios)" \
            "13" "MSSQL & Remote DB Support (sqlsrv/dblib)" \
            "14" "Cambiar Versión de PHP por Dominio" \
            "15" "Restart Apache" \
            "16" "Update Script from GitHub" \
            "17" "Diagnosticar/Reparar SSL (Error RX_RECORD_TOO_LONG)" \
            "18" "Instalar Esenciales para CMS (WebEngine/FusionCMS/etc)" \
            "19" "Instalar WebEngine CMS" \
            "0" "Exit")

        case $CHOICE in
            1) install_apache_php ;;
            2) manage_extensions ;;
            3) install_custom_extension ;;
            4) manage_modules ;;
            5) install_certbot ;;
            6) add_domain ;;
            7) add_ssl_to_existing ;;
            8) list_vhosts ;;
            9) delete_domain ;;
            10) fix_permissions ;;
            11) manage_users ;;
            12) manage_mysql ;;
            13) install_sqlsrv ;;
            14) change_vhost_php ;;
            15) systemctl restart apache2 && msg_box "Restart" "Apache2 has been restarted." ;;
            16) 
                if [ -f "./update.sh" ]; then
                    bash ./update.sh
                    exit 0
                else
                    msg_box "Error" "Update script (update.sh) not found in the current directory."
                fi
                ;;
            17) diagnose_ssl ;;
            18) install_cms_essentials ;;
            19) install_webengine ;;
            0) exit 0 ;;
            *) continue ;;
        esac
    done
}

# Clear screen and start
clear
echo -e "${BLUE}Starting Apache Management Script...${NC}"
main_menu
