#!/bin/bash

cp ./iptables.sh /usr/local/sbin/iptables.sh
chmod u=rwx,og= /usr/local/sbin/iptables.sh

cp ./firewall.conf /etc/init/firewall.conf
chmod u=rw,og=r /etc/init/firewall.conf

sudo ./iptables.sh

echo "Does ssh still work?"
read -t 10 answer
if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
    exit
else
    sudo ./iptables.sh clear
fi

