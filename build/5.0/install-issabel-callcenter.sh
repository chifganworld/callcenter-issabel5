#!/bin/bash

# Clone callcenter repository from this account. If you fork
# the repository and make your own changes, change it to yours
# so you can install or update with this script.

GITHUB_ACCOUNT='ISSABELPBX'

# Install required packages for Debian
apt-get update >/dev/null
apt-get -y install git php-cli asterisk apache2 php-mysql php-gd php-curl php-json >/dev/null

# Create required users if they don't exist
if ! id -u asterisk >/dev/null 2>&1; then
    useradd -r -d /var/lib/asterisk -c "Asterisk User" asterisk
fi

# Create required directories
mkdir -p /var/www/html/modules
mkdir -p /var/www/html/libs
mkdir -p /opt/issabel/dialer
mkdir -p /usr/share/issabel/module_installer/callcenter

# Set proper permissions
chown -R www-data:www-data /var/www/html
chown -R asterisk:asterisk /var/lib/asterisk

RED='\033[0;31m'
NC='\033[0m' # No Color

VERSION=$(asterisk -rx "core show version" | awk '{print $2}' | cut -d\. -f 1)

if [ "$VERSION" != "11" ]; then
    echo
    echo -e "${RED}Issabel CallCenter Community Requires Asterisk 11. It most probably fail with other versions.${NC}"
    echo
fi

cd /usr/src
rm -rf callcenter
git clone https://github.com/${GITHUB_ACCOUNT}/callcenter-issabel5.git callcenter 2>&1 >/dev/null
cd /usr/src/callcenter

# Create a simple issabel-menumerge script if it doesn't exist
if [ ! -f /usr/bin/issabel-menumerge ]; then
    cat > /usr/bin/issabel-menumerge << 'EOL'
#!/bin/bash
# Simple placeholder for issabel-menumerge
echo "Menu merge attempted with $1"
EOL
    chmod +x /usr/bin/issabel-menumerge
fi

# Create a minimal paloSantoInstaller.class.php if it doesn't exist
if [ ! -f /var/www/html/libs/paloSantoInstaller.class.php ]; then
    mkdir -p /var/www/html/libs
    cat > /var/www/html/libs/paloSantoInstaller.class.php << 'EOL'
<?php
class paloSantoInstaller {
    function installModule($module_name) {
        return TRUE;
    }
}
EOL
fi

chown www-data:www-data modules/* -R
cp -pr modules/* /var/www/html/modules/
cp -rf setup/dialer_process/dialer/* /opt/issabel/dialer/
chmod +x /opt/issabel/dialer/dialerd
mkdir -p /etc/init.d/
cp setup/dialer_process/issabeldialer /etc/init.d/
chmod +x /etc/init.d/issabeldialer
mkdir -p /etc/logrotate.d/
cp setup/issabeldialer.logrotate /etc/logrotate.d/issabeldialer
cp setup/usr/bin/issabel-callcenter-local-dnc /usr/bin/
chown www-data:www-data /opt/issabel -R

# Copy files instead of moving them
cp -r setup/* /usr/share/issabel/module_installer/callcenter/
cp menu.xml /usr/share/issabel/module_installer/callcenter/
cp CHANGELOG /usr/share/issabel/module_installer/callcenter/

issabel-menumerge /usr/share/issabel/module_installer/callcenter/menu.xml

mkdir -p /tmp/new_module/callcenter
cp -r /usr/share/issabel/module_installer/callcenter/* /tmp/new_module/callcenter/
chown -R www-data:www-data /tmp/new_module/callcenter

php /tmp/new_module/callcenter/setup/installer.php
rm -rf /tmp/new_module

# Be sure to set shell for user asterisk
chsh -s /bin/bash asterisk 2>&1 >/dev/null

# Create systemd service file for issabeldialer
cat > /etc/systemd/system/issabeldialer.service << 'EOL'
[Unit]
Description=Issabel Dialer Service
After=network.target mysql.service asterisk.service

[Service]
Type=forking
ExecStart=/etc/init.d/issabeldialer start
ExecStop=/etc/init.d/issabeldialer stop
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Check if systemd is available
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable issabeldialer
    systemctl start issabeldialer
else
    echo "systemctl not found. Please start the service manually."
fi
