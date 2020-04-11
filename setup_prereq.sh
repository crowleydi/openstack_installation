#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for Ubuntu 18.04 OpenStack skeleton
# all instances will be cloned from this skeleton.
#

# make sure we are on train
sudo add-apt-repository cloud-archive:train

# update the repository
sudo apt update
sudo apt upgrade

# install the base line packages
sudo apt install chrony python3-openstackclient
