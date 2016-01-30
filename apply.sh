#!/bin/bash

cp ./iptables.sh /usr/local/sbin/iptables.sh
chmod u=rwx,og= /usr/local/sbin/iptables.sh

cp ./iptables-sh.service /etc/systemd/system/iptables-sh.service
chmod 664 /etc/systemd/system/iptables-sh.service

systemctl daemon-reload
systemctl enable iptables-sh.service

echo "Does ssh still work?"
read -t 10 answer
if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
    exit
else
    systemctl disable iptables-sh.service
fi

