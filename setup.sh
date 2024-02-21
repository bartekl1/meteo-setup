#!/bin/bash

# Colors
Color_Off='\033[0m'       # Text Reset
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

echo "*********************************************"
echo "*                Meteo Setup                *"
echo "*     Setup script for my meteo station     *"
echo "*  https://github.com/bartekl1/meteo-setup  *"
echo "*         by @bartekl1       v. 1.0         *"
echo "*********************************************"
echo

if [ "$EUID" -ne 0 ]
then
    echo -e "${Red}Error!${Color_Off} Script must be run as root."
    echo -e "${Blue}Try:${Color_Off} sudo !!"
    exit
fi

echo "===== Raspberry Pi configuration ====="

read -p "Run raspi-config? (y/n) " rpi_config
if [[ $rpi_config =~ ^[Yy]$ ]]
then
    raspi-config
fi

read -p "Open dhcpd config file? (y/n) " dhcpd_config
if [[ $dhcpd_config =~ ^[Yy]$ ]]
then
    nano /etc/dhcpcd.conf
fi

read -p "Open wpa_supplicant config file? (y/n) " wpa_supplicant_config
if [[ $wpa_supplicant_config =~ ^[Yy]$ ]]
then
    nano /etc/wpa_supplicant/wpa_supplicant.conf
fi

echo
echo "===== Installation ====="
read -p "Update system? (y/n) " update_system
read -p "Install apache2? (y/n) " install_apache2
read -p "Install mariadb-server? (y/n) " install_mariadb
read -p "Install php? (y/n) " install_php
read -p "Install phpMyAdmin? (y/n) " install_phpmyadmin
read -p "Install meteo station? (y/n) " install_meteo
read -p "Install ngrok? (y/n) " install_ngrok
read -p "Install zerotier? (y/n) " install_zerotier

echo -e "\n${Blue}Starting installation ...${Color_Off}\n"

if [[ $update_system =~ ^[Yy]$ ]] || [[ $install_apache2 =~ ^[Yy]$ ]] || [[ $install_mariadb =~ ^[Yy]$ ]] || [[ $install_php =~ ^[Yy]$ ]]
then
    echo -e "Updating apt repository ${Blue}...${Color_Off}\n"

    apt update

    echo -e "\nUpdating apt repository ${Green}Done!${Color_Off}"
fi

if [[ $update_system =~ ^[Yy]$ ]]
then
    echo -e "Updating system ${Blue}...${Color_Off}\n"

    apt -y upgrade
    apt -y autoremove

    echo -e "\nUpdating system ${Green}Done!${Color_Off}"
fi

if [[ $install_apache2 =~ ^[Yy]$ ]]
then
    echo -e "Installing apache2 ${Blue}...${Color_Off}\n"

    apt -y install apache2
    mv /var/www/html /var/www/default
    mkdir /var/www/html

    echo -e "\nInstalling apache2 ${Green}Done!${Color_Off}"
fi

if [[ $install_mariadb =~ ^[Yy]$ ]]
then
    echo -e "Installing mariadb-server ${Blue}...${Color_Off}\n"

    apt -y install mariadb-server

    echo -e "\nInstalling mariadb-server ${Green}Done!${Color_Off}"
fi

if [[ $install_php =~ ^[Yy]$ ]]
then
    echo -e "Installing php ${Blue}...${Color_Off}\n"

    apt -y install php libapache2-mod-php php-mysql php-mbstring

    echo -e "\nInstalling php ${Green}Done!${Color_Off}"
fi

if [[ $install_phpmyadmin =~ ^[Yy]$ ]]
then
    echo -e "Installing phpMyAdmin ${Blue}...${Color_Off}\n"

    wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip -P /var/www/html
    unzip /var/www/html/phpMyAdmin-5.2.1-all-languages.zip -d /var/www/html
    rm /var/www/html/phpMyAdmin-5.2.1-all-languages.zip
    mv /var/www/html/phpMyAdmin-5.2.1-all-languages /var/www/html/phpMyAdmin
    mkdir /var/www/html/phpMyAdmin/tmp
    chmod 777 /var/www/html/phpMyAdmin/tmp
    echo -e "<?php\n\$cfg['blowfish_secret'] = '`tr -dc A-Za-z0-9 </dev/urandom | head -c 32; echo`';\n?>" | tee /var/www/html/phpMyAdmin/config.inc.php > /dev/null

    echo -e "\nInstalling phpMyAdmin ${Green}Done!${Color_Off}"
fi

if [[ $install_meteo =~ ^[Yy]$ ]]
then
    echo -e "Installing meteo station ${Blue}...${Color_Off}\n"

    user_home=$(getent passwd $SUDO_USER | cut -d: -f6)
    mysql_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 30; echo)

    git clone https://github.com/bartekl1/meteo.git "${user_home[@]}/meteo"
    raspi-config nonint do_i2c 0
    raspi-config nonint do_onewire 0
    pip install -r "${user_home[@]}/meteo/requirements.txt"
    mysql -e "CREATE DATABASE IF NOT EXISTS meteo;"
    mysql --database=meteo -e "source ${user_home[@]}/meteo/meteo.sql"
    mysql -e "CREATE USER 'meteo'@'localhost' IDENTIFIED BY '${mysql_password[@]}';"
    mysql -e "GRANT SELECT, INSERT ON meteo.readings TO 'meteo'@'localhost';"
    echo -e "{\n    \"flask\": {\n        \"host\": \"0.0.0.0\",\n        \"port\": 5000\n    },\n    \"mysql\": {\n        \"host\": \"127.0.0.1\",\n        \"username\": \"meteo\",\n        \"password\": \"${mysql_password}\",\n        \"database\": \"meteo\"\n    }\n}" | tee "${user_home[@]}/meteo/configs.json" > /dev/null
    echo -e "[Unit]\nDescription=Meteo station\nAfter=network.target\n\n[Service]\nWorkingDirectory=${user_home}/meteo\nExecStart=/usr/bin/python3 ${user_home}/meteo/app.py\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n" | tee /etc/systemd/system/meteo.service > /dev/null
    systemctl start meteo
    systemctl enable meteo
    crontab -l | { cat; echo -e "*/10 * * * * cd ${user_home}/meteo && python3 upload_to_database.py"; } | crontab -
    echo -e "<?php\n\$port = '5000';\nheader('Location: '\n    . (\$_SERVER['HTTPS'] ? 'https' : 'http')\n    . '://' . \$_SERVER['HTTP_HOST'] . ':' . \$port);\nexit;\n?>\n" | tee /var/www/html/index.php > /dev/null

    echo -e "\nInstalling meteo station ${Green}Done!${Color_Off}"
fi

if [[ $install_ngrok =~ ^[Yy]$ ]]
then
    echo -e "Installing ngrok ${Blue}...${Color_Off}\n"

    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list && apt update && apt install ngrok

    echo -e "\nInstalling ngrok ${Green}Done!${Color_Off}"
fi

if [[ $install_zerotier =~ ^[Yy]$ ]]
then
    echo -e "Installing zerotier ${Blue}...${Color_Off}\n"

    curl -s https://install.zerotier.com | bash

    echo -e "\nInstalling zerotier ${Green}Done!${Color_Off}"
fi

echo -e "\n${Green}Installation completed!${Color_Off}\n"

echo "===== Post-installation and configuration ====="

read -p "Set root password for mysql? (y/n) " change_mysql_root_password
if [[ $change_mysql_root_password =~ ^[Yy]$ ]]
then
    read -s -p "Enter new password (will not be echoed): " new_mysql_root_password
    echo -e "\n"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_mysql_root_password[@]}';"
fi

read -p "Run mysql_secure_installation? (y/n) " run_mysql_secure_installation
if [[ $run_mysql_secure_installation =~ ^[Yy]$ ]]
then
    mysql_secure_installation
fi

read -p "Open meteo config file? (y/n) " meteo_config
if [[ $meteo_config =~ ^[Yy]$ ]]
then
    user_home=$(getent passwd $SUDO_USER | cut -d: -f6)

    nano "${user_home[@]}/meteo/configs.json"
fi

read -p "Configure ngrok? (y/n) " configure_ngrok
if [[ $configure_ngrok =~ ^[Yy]$ ]]
then
    user_home=$(getent passwd $SUDO_USER | cut -d: -f6)

    read -p "Enter ngrok authtoken: " ngrok_authtoken
    read -p "Enter ngrok domain: " ngrok_domain

    echo -e "authtoken: ${ngrok_authtoken}\nlog_level: info\nlog_format: json\nlog: /var/log/ngrok.log\nregion: eu\nupdate_check: false\nversion: 2\nweb_addr: localhost:4040\ntunnels:\n  meteo:\n    addr: 5000\n    schemes:\n      - https\n    proto: http\n    domain: ${ngrok_domain}\n" | tee "${user_home[@]}/ngrok.yml" > /dev/null
    echo -e "[Unit]\nDescription=Ngrok\nAfter=network.target\n\n[Service]\nWorkingDirectory=${user_home}\nExecStart=/usr/local/bin/ngrok start --config=ngrok.yml meteo\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n" | tee "/etc/systemd/system/ngrok.service" > /dev/null
    systemctl start ngrok
    systemctl enable ngrok
fi

read -p "Join zerotier network? (y/n) " configure_zerotier
if [[ $configure_zerotier =~ ^[Yy]$ ]]
then
    read -p "Enter zerotier network ID: " zerotier_id

    zerotier-cli join "${zerotier_id[@]}"
fi

echo -e "\n${Green}Installation completed!${Color_Off}\n"
