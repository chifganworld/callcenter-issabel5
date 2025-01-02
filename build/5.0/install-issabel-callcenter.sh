#!/bin/bash

# Clone callcenter repository from this account. If you fork
# the repository and make your own changes, change it to yours
# so you can install or update with this script.

GITHUB_ACCOUNT='ISSABELPBX'

# Install required packages for Debian
apt-get update >/dev/null
apt-get -y install git php-cli >/dev/null

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
chown www-data.www-data modules/* -R
cp -pr modules/* /var/www/html/modules
mkdir -p /opt/issabel/
mv setup/dialer_process/dialer/ /opt/issabel/
chmod +x /opt/issabel/dialer/dialerd
mkdir -p /etc/init.d/
mv setup/dialer_process/issabeldialer /etc/init.d/
chmod +x /etc/init.d/issabeldialer
mkdir -p /etc/logrotate.d/
mv setup/issabeldialer.logrotate /etc/logrotate.d/issabeldialer
mv setup/usr/bin/issabel-callcenter-local-dnc /usr/bin
chown www-data.www-data /opt/issabel -R
rm -rf /usr/share/issabel/module_installer/callcenter/
mkdir -p    /usr/share/issabel/module_installer/callcenter/
mv setup/   /usr/share/issabel/module_installer/callcenter/
mv menu.xml /usr/share/issabel/module_installer/callcenter/
mv CHANGELOG /usr/share/issabel/module_installer/callcenter/

issabel-menumerge /usr/share/issabel/module_installer/callcenter/menu.xml

mkdir -p /tmp/new_module/callcenter
cp -r /usr/share/issabel/module_installer/callcenter/* /tmp/new_module/callcenter/
chown -R www-data.www-data /tmp/new_module/callcenter

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

# Enable and start the service using systemd
systemctl daemon-reload
systemctl enable issabeldialer
systemctl start issabeldialer
