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

echo "===== Raspberry Pi configuration ====="

if [ "$EUID" -ne 0 ]
then
    echo -e "${Red}Error!${Color_Off} Script must be run as root."
    echo -e "${Blue}Try:${Color_Off} sudo !!"
    exit
fi

read -p "Run raspi-config (y/n)? " rpi_config
if [[ $rpi_config =~ ^[Yy]$ ]]
then
    raspi-config
fi

read -p "Open dhcpd config file (y/n)? " dhcpd_config
if [[ $dhcpd_config =~ ^[Yy]$ ]]
then
    nano /etc/dhcpcd.conf
fi

read -p "Open wpa_supplicant config file (y/n)? " wpa_supplicant_config
if [[ $wpa_supplicant_config =~ ^[Yy]$ ]]
then
    nano /etc/wpa_supplicant/wpa_supplicant.conf
fi