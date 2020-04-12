#!/bin/sh
HOSTNAME=$1
IP=$2

NETPLANCONF=/etc/netplan/50-cloud-init.yaml

# regenerate ssh keys for each instance
sudo dpkg-reconfigure openssh-server

# set hostname
echo $HOSTNAME | sudo tee /etc/hostname > /dev/null

# fix the hosts file
sed s/skeleton/$HOSTNAME/ /etc/hosts > /tmp/hosts.conf
sudo cp /tmp/hosts.conf /etc/hosts
rm /tmp/hosts.conf

# fix the network configuration
sed s/10\.0\.0\.5/$IP/ $NETPLANCONF > /tmp/net.conf
sudo cp /tmp/net.conf $NETPLANCONF
rm /tmp/net.conf

sudo reboot
