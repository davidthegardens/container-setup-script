#!/bin/bash
# Use: send-setup.sh [optional: container name] [optional: remote:container_id]
lxcname=${1:-"ocelot"}
container=${2:-"ubuntu:n"}
prebuild="ocelot-2.0.1"
LOCATIONNAME="/var/snap/lxd/common/lxd/containers/${lxcname}/rootfs/home/ubuntu"

sudo -u d mkdir -p "/home/d/.ssh/ocelot-keys"
sudo chown d "/home/d/.ssh/ocelot-keys"
KEYFILELOCATION="/home/d/.ssh/ocelot-keys/container-${lxcname}"

hasBuiltOcelot="false"
while IFS=',' read -r first_column rest_of_line; do
	if [[ "$first_column" == "ocelot-2.0.0" ]]; then
		hasBuiltOcelot="true"
		echo "$first_column"
		break
	fi
done < <(lxc image list -f csv)
echo "hasBuiltOcelot = ${hasBuiltOcelot}"

if [[ "$hasBuiltOcelot" == "true" ]]; then
	lxc launch "$prebuild" $lxcname
else
	lxc launch $container $lxcname
	wait $!
	rm -rf $LOCATIONNAME/container-setup-script
	git clone --depth 1 https://github.com/davidthegardens/container-setup-script.git $LOCATIONNAME/container-setup-script
	sudo touch $LOCATIONNAME/.bashrc
	cp -R "/home/d/.ssh/gh-login" $LOCATIONNAME/.ssh/
	echo 'sudo /home/ubuntu/container-setup-script/setup_container.sh; exit' | cat - $LOCATIONNAME/.bashrc >temp && mv temp $LOCATIONNAME/.bashrc
fi

lxc config device add "$lxcname" ssh-agent proxy connect="unix:${SSH_AUTH_SOCK}" listen="unix:/tmp/host-ssh-agent.sock" bind=container uid=1000 gid=1000 mode=0600
lxc config device add "$lxcname" ssh-dir disk source="${HOME}/.ssh" path="/home/ubuntu/.ssh"

# sudo -u d ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:${lxcname} -C "mail@davidthegardens.com" -f $KEYFILELOCATION

touch "${LOCATIONNAME}/.ssh/authorized_keys"
cat "${KEYFILELOCATION}.pub" >>"${LOCATIONNAME}/.ssh/authorized_keys"
ip_addr_unfmt=$(lxc exec $lxcname -- ip addr show eth0 | grep "inet\b" | awk '{print $2}')
ip_addr="${ip_addr_unfmt:0:-3}"
if [[ "$hasBuiltOcelot" == "false" ]]; then
	lxc exec $lxcname -- sudo -u ubuntu bash
fi

lxc config device add ${lxcname} yubikey usb vendorid=1050 productid=0407
lxc config device add ${lxcname} yubikey-hid0 unix-char path=/dev/hidraw0 mode=0666
lxc config device add ${lxcname} yubikey-hid1 unix-char path=/dev/hidraw1 mode=0666

cat <<EOF >>/home/d/.ssh/config

Host ${lxcname}
  IdentityFile ${KEYFILELOCATION}
  Hostname ${ip_addr}
  User ubuntu
  LocalForward 3000 localhost:3000
  ServerAliveInterval 3600
  ForwardX11 yes
  IdentityAgent none
  SetEnv TERM=xterm-256color

EOF

sudo -u d ssh-keyscan $ip_addr >>/home/d/.ssh/known_hosts
ssh $lxcname
