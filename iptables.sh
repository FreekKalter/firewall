#!/bin/bash

# The location of the IPtables binary file on your system.
IPT="$(which iptables) --wait"
IP6T="$(which ip6tables) --wait"
MODPROBE=$(which modprobe)
# INT_NET=192.168.2.0/24

# The network interface we will be protecting
INT="eth0"

PARENT=$(ps aux | awk -v pid="$PPID" '$2 ~ pid {print $NF}')

# The following rules will clear out any existing firewall rules,
# and any chains that might have been created.
$IPT --flush
$IPT --flush INPUT
$IPT --flush OUTPUT
$IPT --flush FORWARD
$IPT --flush --table mangle
$IPT --flush --table nat
$IPT --delete-chain

# These will setup our policies.
$IPT --policy INPUT ACCEPT
$IPT --policy OUTPUT ACCEPT
$IPT --policy FORWARD ACCEPT

# no ip6 for the time being
$IP6T --flush
$IP6T --flush INPUT
$IP6T --flush OUTPUT
$IP6T --flush FORWARD
$IP6T --policy INPUT DROP
$IP6T --policy OUTPUT DROP
$IP6T --policy FORWARD DROP

echo "Cleared all tables and chains"
if [ "$1" = "clear" ]; then
    exit
fi

### load connection-tracking modules
$MODPROBE ip_conntrack

# The following line below enables IP forwarding and thus
# by extension, NAT. Turn this on if you're going to be
# doing NAT or IP Masquerading.
#echo 1 > /proc/sys/net/ipv4/ip_forward

# Now, our LogAndDrop chain, for the final catchall filter.
$IPT --new-chain LogAndDrop
$IPT --append LogAndDrop --match limit --limit 15/minute --jump LOG --log-prefix "LogAndDrop: "
$IPT --append LogAndDrop --jump DROP

# Our "hey, them's some bad tcp flags!" chain.
$IPT --new-chain badflags
$IPT --append badflags --match limit --limit 15/minute --jump LOG --log-prefix "Badflags: "
$IPT --append badflags --jump DROP

# First lets do some basic state-matching. This allows us
# to accept related and established connections, so
# connections initiated client-side work.
$IPT --insert INPUT --match conntrack --ctstate ESTABLISHED,RELATED --jump ACCEPT


# This rule will accept connections from local machines. If you have
# a home network, enter in the IP's of the machines on the
# network below.
$IPT --append INPUT --in-interface lo --jump ACCEPT
# Allow ip6 only as loopback
$IP6T --append INPUT --in-interface lo --jump ACCEPT
$IP6T --append INPUT --source ::1 --destination 0/0 --protocol all --jump ACCEPT
$IP6T --append OUTPUT --source ::1 --destination 0/0 --protocol all --jump ACCEPT
#$IPT --append INPUT --source $INT_NET --destination 0/0 --protocol all --jump ACCEPT
#$IPT --append INPUT --source 10.1.1.51 --destination 0/0 --protocol all --jump ACCEPT
#$IPT --append INPUT --source 10.1.1.52 --destination 0/0 --protocol all --jump ACCEPT

# Drop those nasty packets! These are all TCP flag
# combinations that should never, ever occur in the
# wild. All of these are illegal combinations that
# are used to attack a box in various ways, so we
# just drop them and log them here.
$IPT --append INPUT --protocol tcp --tcp-flags ALL FIN,URG,PSH --jump badflags
$IPT --append INPUT --protocol tcp --tcp-flags ALL ALL --jump badflags
$IPT --append INPUT --protocol tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG --jump badflags
$IPT --append INPUT --protocol tcp --tcp-flags ALL NONE --jump badflags
$IPT --append INPUT --protocol tcp --tcp-flags SYN,RST SYN,RST --jump badflags
$IPT --append INPUT --protocol tcp --tcp-flags SYN,FIN SYN,FIN --jump badflags


############################################################################################
# Okay, now for our services
############################################################################################

# ssh
$IPT --append INPUT --in-interface $INT --protocol tcp --dport 22 --jump ACCEPT

# Our final trap. Everything on INPUT goes to the LogAndDrop
# so we don't get silent drops.
$IPT --append INPUT --jump LogAndDrop
echo "Applied all iptables rules"
