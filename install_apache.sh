#!/bin/bash

# ==============================================================================
# Modern Apache & PHP Installation Script
# ==============================================================================
# Description: Interactive script to install Apache, modules, PHP extensions, 
#              manage virtual hosts, and change default directories.
# Target OS: Ubuntu / Debian
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
# UI Helper Functions
# ==============================================================================

function msg_box() {
    whiptail --title "$1" --msgbox "$2" 10 60
}

function input_box() {
    whiptail --title "$1" --inputbox "$2" 10 60 "$3" 3>&1 1>&2 2>&3
}

function menu() {
    local title=$1
    local text=$2
    shift 2
    whiptail --title "$title" --menu "$text" 20 70 10 "$@" 3>&1 1>&2 2>&3
}

function checklist() {
    local title=$1
    local text=$2
    shift 2
    whiptail --title "$title" --checklist "$text" 20 70 12 "$@" 3>&1 1>&2 2>&3
}

function yes_no() {
    whiptail --title "$1" --yesno "$2" 10 60
}

# ==============================================================================
# Core Installation Functions
# ==============================================================================

function install_apache_php() {
    msg_box "Instalación de Apache y PHP" "Esta sección instalará el servidor web Apache2 y el lenguaje de programación PHP. Podrás elegir la versión que desees (desde 7.4 hasta la última disponible)."
    
    PHP_VER_CHOICE=$(menu "Seleccionar Versión de PHP" "Elige la versión de PHP que deseas instalar:" \
        "7.4" "PHP 7.4 (Legacy)" \
        "8.0" "PHP 8.0" \
        "8.1" "PHP 8.1" \
        "8.2" "PHP 8.2" \
        "8.3" "PHP 8.3" \
        "8.4" "PHP 8.4 (Latest)")
    
    [ -z "$PHP_VER_CHOICE" ] && return

    echo -e "${CYAN}Adding PPA for PHP versions...${NC}"
    apt-get install -y software-properties-common
    add-apt-repository ppa:ondrej/php -y
    apt-get update
    
    echo -e "${CYAN}Installing Apache2 and PHP $PHP_VER_CHOICE...${NC}"
    apt-get install -y apache2 php$PHP_VER_CHOICE libapache2-mod-php$PHP_VER_CHOICE curl wget unzip
    
    systemctl enable apache2
    systemctl start apache2
    
    msg_box "Success" "Apache2 and PHP $PHP_VER_CHOICE have been installed correctly."
}

function manage_modules() {
    msg_box "Gestión de Módulos" "Los módulos de Apache añaden funciones adicionales al servidor (como reescritura de URL o soporte SSL). Selecciona los que quieras activar."
    MODS=$(checklist "Apache Modules" "Select the modules you want to enable (Space to toggle):" \
        "rewrite" "Redirects & Friendly URLs" ON \
        "ssl" "HTTPS support" ON \
        "headers" "HTTP Header manipulation" OFF \
        "proxy" "Proxy support" OFF \
        "proxy_http" "Proxy HTTP protocol" OFF \
        "expires" "Caching headers" OFF \
        "deflate" "Compression support" OFF \
        "env" "Environment variables" OFF \
        "mime" "Mime types management" OFF \
        "vhost_alias" "Dynamic Virtual Hosts" OFF)
    
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
    msg_box "Extensiones PHP" "Aquí puedes seleccionar de una lista predefinida las extensiones de PHP que necesites. El script detectará tu versión de PHP e instalará los paquetes correspondientes."
    EXTS=$(checklist "PHP Extensions" "Select the extensions (Space to toggle, Up/Down to scroll):" \
        "40-vld" "vld extension" OFF \
        "amqp" "AMQP protocol" OFF \
        "apcu" "APCu cache" OFF \
        "bcmath" "High precision math" OFF \
        "bitset" "Bitset management" OFF \
        "brotli" "Brotli compression" OFF \
        "bz2" "Bzip2 compression" OFF \
        "calendar" "Calendar conversion" OFF \
        "core" "Core PHP" ON \
        "ctype" "Ctype functions" ON \
        "curl" "CURL HTTP client" ON \
        "date" "Date & Time" ON \
        "dba" "Database abstraction" OFF \
        "dbase" "dBase files" OFF \
        "diseval" "Diseval (Disabled Eval)" OFF \
        "dom" "DOM support" ON \
        "eio" "EIO extension" OFF \
        "elastic_apm" "Elastic APM" OFF \
        "enchant" "Spell checking" OFF \
        "exif" "Image metadata" OFF \
        "ffi" "Foreign Function Interface" OFF \
        "fileinfo" "Fileinfo support" ON \
        "filter" "Filter input" ON \
        "ftp" "FTP functions" ON \
        "gd" "GD Image library" ON \
        "gearman" "Gearman support" OFF \
        "gender" "Gender database" OFF \
        "geoip" "GeoIP database" OFF \
        "geos" "GEOS support" OFF \
        "gettext" "Translation support" OFF \
        "gmagick" "GraphicsMagick" OFF \
        "gmp" "GNU Multiple Precision" OFF \
        "gnupg" "GnuPG support" OFF \
        "grpc" "gRPC support" OFF \
        "hash" "Hash functions" ON \
        "htscanner" "htscanner extension" OFF \
        "http" "HTTP extension" OFF \
        "iconv" "Iconv conversion" ON \
        "igbinary" "Binary serialization" OFF \
        "imagick" "ImageMagick library" OFF \
        "imap" "IMAP/POP3 support" OFF \
        "inotify" "Inotify support" OFF \
        "intl" "Internationalization" OFF \
        "ioncube_loader" "IonCube loader" OFF \
        "jsmin" "Javascript Minifier" OFF \
        "json" "JSON support" ON \
        "ldap" "LDAP support" OFF \
        "leveldb" "LevelDB support" OFF \
        "libxml" "LibXML support" ON \
        "luasandbox" "Lua sandbox" OFF \
        "lzf" "LZF compression" OFF \
        "mailparse" "Email parsing" OFF \
        "mbstring" "Multibyte string support" ON \
        "mcrypt" "Encryption library" OFF \
        "memcache" "Memcached support" OFF \
        "memcached" "Memcached (Libmemcached)" OFF \
        "mongodb" "MongoDB driver" OFF \
        "msgpack" "MessagePack" OFF \
        "mysqli" "MySQLi driver" ON \
        "mysqlnd" "MySQL Native Driver" ON \
        "nd_mysqli" "MySQLnd MySQLi" OFF \
        "nd_pdo_mysql" "MySQLnd PDO MySQL" OFF \
        "newrelic" "New Relic agent" OFF \
        "oauth" "OAuth support" OFF \
        "oci8" "Oracle OCI8" OFF \
        "odbc" "ODBC support" OFF \
        "opcache" "OPcache" ON \
        "openssl" "OpenSSL support" ON \
        "pcntl" "Process Control" OFF \
        "pcre" "Perl Regex" ON \
        "pdf" "PDF library" OFF \
        "pdo" "PDO core" ON \
        "pdo_dblib" "PDO Sybase/MS-SQL" OFF \
        "pdo_firebird" "PDO Firebird" OFF \
        "pdo_mysql" "PDO MySQL" ON \
        "pdo_oci" "PDO Oracle OCI" OFF \
        "pdo_odbc" "PDO ODBC" OFF \
        "pdo_pgsql" "PDO PostgreSQL" OFF \
        "pdo_snowflake" "PDO Snowflake" OFF \
        "pdo_sqlite" "PDO SQLite" ON \
        "pdo_sqlsrv" "PDO MS SQL Server" OFF \
        "pgsql" "PostgreSQL support" OFF \
        "phalcon5" "Phalcon 5 framework" OFF \
        "phar" "PHAR support" ON \
        "phpiredis" "Hiredis driver" OFF \
        "posix" "POSIX functions" ON \
        "protobuf" "Protobuf support" OFF \
        "pspell" "Pspell library" OFF \
        "psr" "PSR interfaces" OFF \
        "raphf" "RAPHF extension" OFF \
        "rar" "RAR archive" OFF \
        "readline" "Readline support" ON \
        "redis" "Redis cache support" OFF \
        "reflection" "Reflection classes" ON \
        "rrd" "RRDtool support" OFF \
        "scoutapm" "Scout APM" OFF \
        "session" "Session support" ON \
        "shmop" "Shared memory" ON \
        "simplexml" "SimpleXML support" ON \
        "snmp" "SNMP support" OFF \
        "snuffleupagus" "Snuffleupagus security" OFF \
        "soap" "SOAP protocol" OFF \
        "sockets" "Socket support" OFF \
        "sodium" "Sodium encryption" ON \
        "solr" "Apache Solr" OFF \
        "sourceguardian" "SourceGuardian" OFF \
        "spl" "SPL support" ON \
        "sqlite3" "SQLite database" ON \
        "sqlsrv" "MS SQL Server" OFF \
        "ssh2" "SSH2 support" OFF \
        "standard" "Standard PHP" ON \
        "stats" "Statistics" OFF \
        "swoole" "Swoole engine" OFF \
        "sysvmsg" "System V messages" OFF \
        "sysvsem" "System V semaphores" OFF \
        "sysvshm" "System V shared memory" OFF \
        "tideways_xhprof" "Tideways XHProf" OFF \
        "tidy" "Tidy support" OFF \
        "timezonedb" "Timezone database" OFF \
        "tokenizer" "Tokenizer support" ON \
        "trader" "Stock trader" OFF \
        "uploadprogress" "Upload tracking" OFF \
        "uuid" "UUID support" OFF \
        "vips" "VIPS library" OFF \
        "xdebug" "Debugger/Profiler" OFF \
        "xdiff" "Diff/Patch" OFF \
        "xml" "XML support" ON \
        "xmlreader" "XML Reader" ON \
        "xmlrpc" "XMLRPC protocol" OFF \
        "xmlwriter" "XML Writer" ON \
        "xsl" "XSLT support" OFF \
        "yaf" "YAF framework" OFF \
        "yaml" "YAML support" OFF \
        "yaz" "YAZ support" OFF \
        "zip" "Zip file handling" ON \
        "zlib" "Zlib compression" ON)
    
    if [ -n "$EXTS" ]; then
        # Detect PHP version
        PHP_VERS=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
        
        echo -e "${CYAN}Installing selected PHP extensions for PHP $PHP_VERS...${NC}"
        # Remove quotes from whiptail output
        EXTS=$(echo $EXTS | sed 's/"//g')
        # Prepend php- to each extension name for apt
        APT_EXTS=""
        for ext in $EXTS; do
            # Use phpX.X- style for better compatibility if possible, or generic if not
            APT_EXTS="$APT_EXTS php$PHP_VERS-$ext"
        done
        
        # Test if phpX.X-ext exists, if not fallback to php-ext
        # We suppress errors for core extensions that don't have separate packages
        apt-get install -y $APT_EXTS 2>/dev/null || apt-get install -y $(echo $EXTS | sed "s/ / php-/g" | sed "s/^/php-/") 2>/dev/null
        
        systemctl restart apache2
        msg_box "Success" "The selected PHP extensions have been installed."
    fi
}

function install_certbot() {
    msg_box "Instalación de Certbot" "Certbot es una herramienta para automatizar el uso de certificados SSL de Let's Encrypt, permitiendo que tu sitio sea seguro (HTTPS) de forma gratuita."
    echo -e "${CYAN}Installing Certbot for Apache...${NC}"
    apt-get update
    apt-get install -y certbot python3-certbot-apache
    msg_box "Success" "Certbot has been installed correctly and is ready for use."
}

function add_ssl_to_existing() {
    msg_box "SSL para Dominio Existente" "Esta opción permite agregar un certificado SSL de Let's Encrypt a un dominio que ya haya sido configurado o ingresar uno manualmente."
    
    # List available configs, excluding defaults and ssl
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vpx "000-default" | grep -vpx "default-ssl")
    
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
    
    # Check DNS resolution
    echo -e "${CYAN}Verificando DNS para $DOMAIN...${NC}"
    if ! host "$DOMAIN" &> /dev/null; then
        msg_box "Advertencia DNS" "El dominio $DOMAIN no parece resolver a ninguna IP. Certbot podría fallar.\nVerifica tus registros A en el panel de tu dominio."
    fi

    echo -e "${CYAN}Running Certbot for $DOMAIN...${NC}"
    if [ $INCLUDE_WWW -eq 0 ]; then
        if ! host "www.$DOMAIN" &> /dev/null; then
             yes_no "Advertencia WWW" "El dominio 'www.$DOMAIN' no resuelve por DNS. ¿Deseas intentar continuar de todas formas? (Se recomienda No si no tienes el registro CNAME/A creado)"
             if [ $? -ne 0 ]; then
                 INCLUDE_WWW=1 # Force no WWW
             fi
        fi
    fi

    if [ $INCLUDE_WWW -eq 0 ]; then
        certbot --apache -d "$DOMAIN" -d "www.$DOMAIN"
    else
        certbot --apache -d "$DOMAIN"
    fi
    
    if [ $? -eq 0 ]; then
        msg_box "SSL Exitoso" "Certificado SSL configurado correctamente para $DOMAIN."
    else
        msg_box "Error" "Hubo un problema al generar el certificado.\n1. Verifica que el dominio apunte a la IP de este servidor.\n2. Asegúrate de que el puerto 80 esté abierto."
    fi
}

function add_domain() {
    msg_box "Nuevo Host Virtual" "Esta herramienta creará un nuevo archivo de configuración de Virtual Host, creará la carpeta para tu sitio y, si lo deseas, configurará el certificado SSL con Certbot."
    DOMAIN=$(input_box "Domain Name" "Enter the domain name (e.g., example.com):" "example.com")
    [ -z "$DOMAIN" ] && return
    
    VPATH=$(input_box "Document Root" "Enter the full path for this domain:" "/var/www/$DOMAIN")
    [ -z "$VPATH" ] && return
    
    echo -e "${CYAN}Creating directory and setting permissions...${NC}"
    mkdir -p "$VPATH"
    
    # Identify potential users for ownership (non-system users)
    USERS=$(awk -F' ' '{ if ($3 >= 1000 && $3 != 65534) print $1 }' /etc/passwd)
    USER_OPTIONS=()
    for u in $USERS; do
        USER_OPTIONS+=("$u" "Usuario del Sistema")
    done
    USER_OPTIONS+=("www-data" "Web Server User")
    
    OWNER=$(menu "Seleccionar Dueño (SFTP)" "Selecciona el usuario que será dueño de los archivos para acceso SFTP/SSH:" "${USER_OPTIONS[@]}")
    [ -z "$OWNER" ] && OWNER="www-data"
    
    chown -R "$OWNER:www-data" "$VPATH"
    find "$VPATH" -type d -exec chmod 775 {} +
    find "$VPATH" -type f -exec chmod 664 {} +
    
    # Add user to www-data group if not already
    if [ "$OWNER" != "www-data" ]; then
        usermod -a -G www-data "$OWNER"
    fi
    
    # Create index file if not exists
    if [ ! -f "$VPATH/index.html" ]; then
        echo "<h1>Welcome to $DOMAIN</h1>" > "$VPATH/index.html"
    fi
    
    CONF_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
    
    echo -e "${CYAN}Creating virtual host configuration...${NC}"
    cat > "$CONF_FILE" <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $VPATH
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    <Directory $VPATH>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
    
    a2ensite "$DOMAIN.conf"
    systemctl restart apache2
    
    # SSL Support with Certbot
    yes_no "SSL Support" "Do you want to configure SSL for $DOMAIN using Certbot?"
    if [ $? -eq 0 ]; then
        if ! command -v certbot &> /dev/null; then
            echo -e "${YELLOW}Certbot not found. Installing now...${NC}"
            apt-get install -y certbot python3-certbot-apache
        fi
        # Check DNS resolution
        echo -e "${CYAN}Verificando DNS para $DOMAIN...${NC}"
        if ! host "$DOMAIN" &> /dev/null; then
            echo -e "${YELLOW}Warning: $DOMAIN does not resolve to an IP. SSL might fail.${NC}"
        fi

        echo -e "${CYAN}Running Certbot for $DOMAIN...${NC}"
        # Check if www resolves before adding it
        if host "www.$DOMAIN" &> /dev/null; then
             certbot --apache -d "$DOMAIN" -d "www.$DOMAIN"
        else
             certbot --apache -d "$DOMAIN"
        fi
    fi
    
    msg_box "Success" "Virtual Host for $DOMAIN has been created and enabled.\nSSL setup attempted if requested.\nPath: $VPATH"
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
    AVAILABLE_SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vpx "000-default" | grep -vpx "default-ssl")
    
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
        "4" "Enable site (a2ensite)")

    case $ACTION in
        1) systemctl status apache2 | head -n 20 && read -p "Press enter to return" ;;
        2) nano "/etc/apache2/sites-available/$SELECTED_SITE.conf" ;;
        3) a2dissite "$SELECTED_SITE" && systemctl restart apache2 && msg_box "Success" "Site disabled." ;;
        4) a2ensite "$SELECTED_SITE" && systemctl restart apache2 && msg_box "Success" "Site enabled." ;;
    esac
}

function install_custom_extension() {
    msg_box "Extensión Personalizada" "Si la extensión que buscas no está en la lista, puedes escribir su nombre aquí. El script intentará buscarla e instalarla usando los repositorios de tu sistema."
    EXT_NAME=$(input_box "Custom PHP Extension" "Enter the name of the PHP extension to install (without php- prefix):" "")
    [ -z "$EXT_NAME" ] && return
    
    PHP_VERS=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    
    echo -e "${CYAN}Attempting to install php$PHP_VERS-$EXT_NAME...${NC}"
    apt-get update
    if apt-get install -y "php$PHP_VERS-$EXT_NAME" || apt-get install -y "php-$EXT_NAME"; then
        systemctl restart apache2
        msg_box "Success" "Extension $EXT_NAME has been installed."
    else
        msg_box "Error" "Could not find package for $EXT_NAME. Try checking the name on PECL or apt."
    fi
}

function fix_permissions() {
    msg_box "Reparar Permisos (SFTP/SSH)" "Esta herramienta ajustará el dueño y los permisos de un sitio para que puedas editar archivos vía SFTP/SSH sin problemas."
    
    # List available configs
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vpx "000-default" | grep -vpx "default-ssl")
    
    if [ -z "$SITES" ]; then
        msg_box "Info" "No se encontraron Virtual Hosts para reparar."
        return
    fi
    
    OPTIONS=()
    for site in $SITES; do
        OPTIONS+=("$site" "Configuración detectada")
    done
    
    DOMAIN=$(menu "Seleccionar Dominio" "Elige el dominio cuyos permisos deseas reparar:" "${OPTIONS[@]}")
    [ -z "$DOMAIN" ] && return
    
    # Identify DocumentRoot
    VPATH=$(grep "DocumentRoot" "/etc/apache2/sites-available/$DOMAIN.conf" | awk '{print $2}' | head -n 1)
    
    if [ -z "$VPATH" ] || [ ! -d "$VPATH" ]; then
        msg_box "Error" "No se pudo encontrar la carpeta del sitio o no existe."
        return
    fi
    
    # User selection
    USERS=$(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1 }' /etc/passwd)
    USER_OPTIONS=()
    for u in $USERS; do
        USER_OPTIONS+=("$u" "Usuario del Sistema")
    done
    USER_OPTIONS+=("www-data" "Web Server User")
    
    OWNER=$(menu "Seleccionar Dueño" "Elige el usuario que debe tener permisos de edición (ej: tu usuario de login):" "${USER_OPTIONS[@]}")
    [ -z "$OWNER" ] && return
    
    echo -e "${CYAN}Fixing permissions for $VPATH...${NC}"
    chown -R "$OWNER:www-data" "$VPATH"
    find "$VPATH" -type d -exec chmod 775 {} +
    find "$VPATH" -type f -exec chmod 664 {} +
    
    if [ "$OWNER" != "www-data" ]; then
        usermod -a -G www-data "$OWNER"
    fi
    
    msg_box "Éxito" "Permisos reparados para $DOMAIN.\nDueño: $OWNER\nGrupo: www-data\nModo: 775/664"
}

function delete_domain() {
    msg_box "Eliminar Virtual Host" "CUIDADO: Esta opción eliminará la configuración del dominio y, si lo deseas, también todos sus archivos."
    
    # List available configs, excluding current defaults
    SITES=$(ls /etc/apache2/sites-available/ | grep ".conf$" | sed 's/.conf$//' | grep -vpx "000-default" | grep -vpx "default-ssl")
    
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
            "10" "Fix Permissions (SFTP/SSH)" \
            "11" "Change Default DocumentRoot" \
            "12" "Restart Apache" \
            "13" "Update Script from GitHub" \
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
            11) change_root ;;
            12) systemctl restart apache2 && msg_box "Restart" "Apache2 has been restarted." ;;
            13) 
                if [ -f "./update.sh" ]; then
                    bash ./update.sh
                    exit 0
                else
                    msg_box "Error" "Update script (update.sh) not found in the current directory."
                fi
                ;;
            0|*) exit 0 ;;
        esac
    done
}

# Clear screen and start
clear
echo -e "${BLUE}Starting Apache Management Script...${NC}"
main_menu
