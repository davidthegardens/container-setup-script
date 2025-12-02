#!/bin/bash

echo "Enter the lxc name: "
read lxcname
LOCATIONNAME="/var/snap/lxd/common/lxd/containers/${lxcname}/rootfs/home/ubuntu"
KEYFILELOCATION="/home/d/.ssh/container-${lxcname}"
rm -rf $LOCATIONNAME/container-setup-script
git clone --depth 1 https://github.com/davidthegardens/container-setup-script.git $LOCATIONNAME/container-setup-script
echo 'sudo ./container-setup-script/setup.sh' | cat - $LOCATIONNAME/.bashrc > temp && mv temp $LOCATIONNAME/.bashrc

sudo -u d ssh-keygen -t ed25519 -f $KEYFILELOCATION
cat "${KEYFILELOCATION}.pub" >> "${LOCATIONNAME}/.ssh/authorized_keys"
ip_addr_unfmt=$(lxc exec $lxcname -- ip addr show eth0 | grep "inet\b" | awk '{print $2}')
ip_addr="${ip_addr_unfmt:0:-3}"

cat <<EOF >> /home/d/.ssh/config

Host ${lxcname}
  Hostname ${ip_addr}
  User ubuntu
  LocalForward 3000 localhost:3000
  ServerAliveInterval 3600
  ForwardX11 yes
  SetEnv TERM=xterm-256color

EOF


sudo -u d ssh-keyscan $ip_addr >> /home/d/.ssh/known_hosts
