#!/bin/bash

# Functions:
enable() { sudo sed -i "s/^\([#;]\)\(\s*${1}\)/\2/" "$2"; }
disable() { sudo sed -i "/^[^#;]\s*${1}\s*=/s/^/#/" "$2"; }
edit() {
    grep -qE "^[#;]?\s*${1}\b" "$3" || echo "${1} ${2}" >> "$3"
    sudo sed -i "s/^\([#;]\s*\)\?\(${1}\)\b.*/\2 ${2}/" "$3"
}
lower() { echo "$1" | awk '{print tolower($0)}'; }

cwd=$(dirname $(readlink -f $0))
user=${SUDO_USER:-$USER}
echo "[FirstRun] Testing for Sudo Rights... "
has_sudo_rights=$(sudo -l &>/dev/null && echo true || echo false)
if $has_sudo_rights; then echo "Sudo OK"; else echo "User dont have Sudo Rights"; exit 1; fi;
echo "[FirstRun] Is $user right user ? (y/n)";read opt
if [ "$(lower $opt)" = "y" ]; then echo "OK"; else echo "Enter Username: "; read user; fi;
echo "[FirstRun] Running Updates..."
sudo apt-get update -y && sudo apt-get upgrade -y 
echo "[FirstRun] Updates Done"


# Samba & DLNA
echo "[FirstRun] Install Samba & DLNA ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
sudo apt install samba samba-common-bin minidlna -y
fi

# Apache2 & PHP
echo "[FirstRun] Install Apache2 & Php ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
sudo apt install php apache2 -y
fi

# NFS Server
echo "[FirstRun] Install NFS Server ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
sudo apt install nfs-kernel-server
fi

# SSH
echo "[FirstRun][SSH] Change Port ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then echo "New Port: "; read sshPort; edit "Port" "$sshPort" "/etc/ssh/sshd_config"; fi
echo "[FirstRun][SSH] Disable Root Login ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then edit "PermitRootLogin" "no" "/etc/ssh/sshd_config"; fi
echo "[FirstRun][SSH] Enable Public Key Auth ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then edit "PubkeyAuthentication" "yes" "/etc/ssh/sshd_config"; fi

enable "AuthorizedKeysFile" "/etc/ssh/sshd_config"

# SUDO
echo "[FirstRun] Set sudo to dont require you Password ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$user" > /dev/null
sudo chmod 0440 "/etc/sudoers.d/$user"
fi

# Enable Autologin
echo "[FirstRun] Enable Autologin ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
enable "NAutoVTs" "/etc/systemd/logind.conf"
enable "ReserveVT" "/etc/systemd/logind.conf"
sudo mkdir /etc/systemd/system/getty@tty1.service.d/
sudo bash -c "cat >> /etc/systemd/system/getty@tty1.service.d/override.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin ${user} %I $TERM
Type=idle
EOL"
fi

# Change Host
echo "[FirstRun] Change Host ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
echo "[chng_host] New Hostname: ";read newhost
echo "$newhost" | sudo tee /etc/hostname
sudo sed -i "s|^127.0.1.1.*|127.0.1.1   ${newhost}|g" /etc/hosts
sudo hostnamectl set-hostname $newhost
fi

# Automatic Updates
echo "[FirstRun] Enable Unattended Upgrades ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades
fi

# Create on-boot & on-shutdown Services
boot_sh="/usr/local/bin/on-boot.sh"; shutdown_sh="/usr/local/bin/on-shutdown.sh"
sudo sh "$cwd/util/on_services.sh" "$boot_sh" "$shutdown_sh"

# MariaDB
#echo "[MariaDB] New MySQL Root Password: "; read MYSQL_PASSWD
#sudo sh $cwd/packages/mariadb.sh "$MYSQL_PASSWD";MYSQL_PASSWD=""

echo "Reboot System ? (y/n)";read opt; if [ "$(lower $opt)" = "y" ]; then sudo reboot; else exit 0; fi