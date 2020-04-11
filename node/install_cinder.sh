#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# block node cinder service
#

if [ -b "/dev/sdb" ]; then
# cool
else
	echo "Must have a /dev/sdb device!"
	exit 1;
fi


#
# install pre-requisites
#
sudo apt install lvm2 thin-provisioning-tools


# create the volume
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb

#
# fix the filter in lvm.conf
#
sed 's/# filter = \[ "r|/dev/cdrom|" \]/filter = [ "a/sdb/", "r/.*/"]/' /etc/lvm/lvm.conf > /tmp/lvmconf
cp /tmp/lvmconf /etc/lvm/lvm.conf
rm /tmp/lvmconf

#
# install and configure components
#
sudo apt install cinder-volume
cat <<EOF | sudo tee /etc/cinder/cinder.conf > /dev/null
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@controller
auth_strategy = keystone
my_ip = $IP
enabled_backends = lvm
glance_api_servers = http://controller:9292

[database]
connection = mysql+pymysql://cinder:$CINDER_DBPASS@controller/cinder

[keystone_authtoken]
www_authenticate_uri = http://controller:5000/
auth_url = http://controller:5000/
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = cinder
password = $CINDER_PASS

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = tgtadm

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = $PLACEMENT_PASS

[neutron]
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS
EOF

sudo service tgt restart
sudo service cinder-volume restart
