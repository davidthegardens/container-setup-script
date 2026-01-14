lxc launch ocelot-2.0.0 $1
ip_addr_unfmt=${$(lxc exec $1 -- ip addr show eth0 | grep "inet\b" | awk '{print $2}'):0:-3}
ip_addr="${ip_addr_unfmt:0:-3}"
