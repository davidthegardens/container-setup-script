cwd=$(pwd)
git clone https://github.com/davidthegardens/container-setup-script.git $cwd
cd "$cwd/container-setup-script"
zshrc_file=$(echo $(cd /home && find /home/* -name .zshrc))

snap install lxd
usermod -aG lxd "$USER"
newgrp lxd
lxd init --minimal

./setup_client.sh $1 $2

lxc stop ${1:-"ocelot"}

lxc export ${1:-"ocelot"} ocelot
