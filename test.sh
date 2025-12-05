# ip_dirty=$(lxc network get lxdbr0 ipv4.address)
# ip="${ip_dirty:0:-3}"

ip_addr_unfmt=$(lxc network get lxdbr0 ipv4.address)
ip_addr="${ip_addr_unfmt:0:-3}"

echo ${ip_addr}
# sudo resolvectl dns lxdbr0 $ip:0:-3
# sudo resolvectl domain lxdbr0 ~lxd
