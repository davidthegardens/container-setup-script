#!/bin/bash
# Use: send-setup.sh [optional: container name] [optional: remote:container_id]
lxcname=${1:-"ocelot"}
container=${2:-"ubuntu:n"}

hasBuiltOcelot="false"
while IFS=',' read -r first_column rest_of_line; do
	if [[ "$first_column" == "ocelot-2.0.0" ]]; then
		hasBuiltOcelot="true"
		echo "$first_column"
		break
	fi
done < <(lxc image list -f csv)
echo "hasBuiltOcelot = ${hasBuiltOcelot}"

if [$hasBuiltOcelot == "true"]; then
	lxc launch "ocelot-2.0.0" $lxcname
else
	lxc launch $container $lxcname
	wait $!
	LOCATIONNAME="/var/snap/lxd/common/lxd/containers/${lxcname}/rootfs/home/ubuntu"
	KEYFILELOCATION="/home/d/.ssh/container-${lxcname}"
	rm -rf $LOCATIONNAME/container-setup-script
	git clone --depth 1 https://github.com/davidthegardens/container-setup-script.git $LOCATIONNAME/container-setup-script
	sudo touch $LOCATIONNAME/.bashrc
	echo 'sudo /home/ubuntu/container-setup-script/setup_container.sh; exit' | cat - $LOCATIONNAME/.bashrc >temp && mv temp $LOCATIONNAME/.bashrc
fi

sudo -u d ssh-keygen -t ed25519 -f $KEYFILELOCATION
touch "${LOCATIONNAME}/.ssh/authorized_keys"
cat "${KEYFILELOCATION}.pub" >>"${LOCATIONNAME}/.ssh/authorized_keys"
ip_addr_unfmt=$(lxc exec $lxcname -- ip addr show eth0 | grep "inet\b" | awk '{print $2}')
ip_addr="${ip_addr_unfmt:0:-3}"
lxc exec $lxcname -- sudo -u ubuntu bash

cat <<EOF >>/home/d/.ssh/config

Host ${lxcname}
  IdentityFile ${KEYFILELOCATION}.pub
  Hostname ${ip_addr}
  User ubuntu
  LocalForward 3000 localhost:3000
  ServerAliveInterval 3600
  ForwardX11 yes
  SetEnv TERM=xterm-256color

EOF

sudo -u d ssh-keyscan $ip_addr >>/home/d/.ssh/known_hosts
