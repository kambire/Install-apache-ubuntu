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
    echo -e "${CYAN}Updating package lists...${NC}"
    apt-get update
    
    echo -e "${CYAN}Installing Apache2, PHP and essential tools...${NC}"
    apt-get install -y apache2 php libapache2-mod-php curl wget unzip
    
    systemctl enable apache2
    systemctl start apache2
    
    PHP_V=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    msg_box "Success" "Apache2 and PHP $PHP_V have been installed correctly."
}

function manage_modules() {
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
    EXTS=$(checklist "PHP Extensions" "Select the extensions you want to install (Space to toggle):" \
        "amqp" "AMQP protocol" OFF \
        "apcu" "APCu cache" OFF \
        "bcmath" "High precision math" OFF \
        "bitset" "Bitset management" OFF \
        "brotli" "Brotli compression" OFF \
        "bz2" "Bzip2 compression" OFF \
        "calendar" "Calendar conversion" OFF \
        "curl" "CURL HTTP client" ON \
        "dba" "Database abstraction" OFF \
        "dbase" "dBase files" OFF \
        "dom" "DOM support" ON \
        "enchant" "Spell checking" OFF \
        "exif" "Image metadata" OFF \
        "ffi" "Foreign Function Interface" OFF \
        "gd" "GD Image library" ON \
        "gettext" "Translation support" OFF \
        "gmagick" "GraphicsMagick" OFF \
        "gmp" "GNU Multiple Precision" OFF \
        "gnupg" "GnuPG support" OFF \
        "grpc" "gRPC support" OFF \
        "http" "HTTP extension" OFF \
        "igbinary" "Binary serialization" OFF \
        "imagick" "ImageMagick library" OFF \
        "imap" "IMAP/POP3 support" OFF \
        "intl" "Internationalization" OFF \
        "ldap" "LDAP support" OFF \
        "lzf" "LZF compression" OFF \
        "mailparse" "Email parsing" OFF \
        "mbstring" "Multibyte string support" ON \
        "mcrypt" "Encryption library" OFF \
        "memcache" "Memcached support" OFF \
        "memcached" "Memcached (Libmemcached)" OFF \
        "mongodb" "MongoDB driver" OFF \
        "msgpack" "MessagePack" OFF \
        "mysql" "MySQL support" ON \
        "mysqli" "MySQLi driver" ON \
        "oauth" "OAuth support" OFF \
        "odbc" "ODBC support" OFF \
        "opcache" "Zend Optimizer" ON \
        "pcntl" "Process Control" OFF \
        "pdf" "PDF creation" OFF \
        "pdo" "PDO core" ON \
        "pgsql" "PostgreSQL support" OFF \
        "pspell" "Pspell library" OFF \
        "psr" "PSR interfaces" OFF \
        "redis" "Redis cache support" OFF \
        "rrd" "RRDtool support" OFF \
        "shmop" "Shared memory" OFF \
        "simplexml" "SimpleXML support" ON \
        "snmp" "SNMP support" OFF \
        "soap" "SOAP protocol" OFF \
        "sockets" "Socket support" OFF \
        "sodium" "Sodium encryption" OFF \
        "solr" "Apache Solr" OFF \
        "sqlite3" "SQLite database" OFF \
        "ssh2" "SSH2 support" OFF \
        "stats" "Statistics" OFF \
        "swoole" "Swoole engine" OFF \
        "sysvmsg" "System V messages" OFF \
        "sysvsem" "System V semaphores" OFF \
        "sysvshm" "System V shared memory" OFF \
        "tidy" "Tidy support" OFF \
        "uploadprogress" "Upload tracking" OFF \
        "uuid" "UUID support" OFF \
        "vips" "VIPS library" OFF \
        "xdebug" "Debugger/Profiler" OFF \
        "xdiff" "Diff/Patch" OFF \
        "xml" "XML support" ON \
        "xmlreader" "XML Reader" OFF \
        "xmlrpc" "XMLRPC protocol" OFF \
        "xmlwriter" "XML Writer" OFF \
        "xsl" "XSLT support" OFF \
        "yaml" "YAML support" OFF \
        "zip" "Zip file handling" ON)
    
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
        apt-get install -y $APT_EXTS || apt-get install -y $(echo $EXTS | sed "s/ / php-/g" | sed "s/^/php-/")
        
        systemctl restart apache2
        msg_box "Success" "The selected PHP extensions have been installed."
    fi
}

function add_domain() {
    DOMAIN=$(input_box "Domain Name" "Enter the domain name (e.g., example.com):" "example.com")
    [ -z "$DOMAIN" ] && return
    
    VPATH=$(input_box "Document Root" "Enter the full path for this domain:" "/var/www/$DOMAIN")
    [ -z "$VPATH" ] && return
    
    echo -e "${CYAN}Creating directory and setting permissions...${NC}"
    mkdir -p "$VPATH"
    chown -R $USER:$USER "$VPATH"
    chmod -R 755 "$VPATH"
    
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
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <Directory $VPATH>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
    
    a2ensite "$DOMAIN.conf"
    systemctl restart apache2
    
    msg_box "Success" "Virtual Host for $DOMAIN has been created and enabled.\nPath: $VPATH"
}

function change_root() {
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
            "5" "Add New Virtual Host (Domain)" \
            "6" "List/Manage Virtual Hosts" \
            "7" "Change Default DocumentRoot" \
            "8" "Restart Apache" \
            "0" "Exit")

        case $CHOICE in
            1) install_apache_php ;;
            2) manage_extensions ;;
            3) install_custom_extension ;;
            4) manage_modules ;;
            5) add_domain ;;
            6) list_vhosts ;;
            7) change_root ;;
            8) systemctl restart apache2 && msg_box "Restart" "Apache2 has been restarted." ;;
            0|*) exit 0 ;;
        esac
    done
}

# Clear screen and start
clear
echo -e "${BLUE}Starting Apache Management Script...${NC}"
main_menu
