#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# compute node nova service
#

sudo apt-get -y install neutron-linuxbridge-agent

cat <<EOF | sudo tee /etc/neutron/neutron.conf > /dev/null
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@controller
auth_strategy = keystone

[keystone_authtoken]
www_authenticate_uri = http://controller:5000/
auth_url = http://controller:5000/
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = $NEUTRON_PASS

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
EOF

sudo service nova-compute restart
sudo service neutron-linuxbridge-agent restart
