#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for Ubuntu 18.04 OpenStack
# to make the skeleton image.
#

# make sure we are on train
sudo add-apt-repository cloud-archive:train

# update the repository
sudo apt update
sudo apt-get -y upgrade

# install the base line packages
sudo apt-get -y install chrony python3-openstackclient

# add some default machines to /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts > /dev/null
#
# default openstack machines
#
10.0.0.11	controller
10.0.0.31	compute1
10.0.0.32	compute2
10.0.0.41	block1
10.0.0.42	block2
10.0.0.51	object1
10.0.0.52	object2
EOF

#
# get the scripts
git clone https://github.com/crowleydi/openstack_installation.git
