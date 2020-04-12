#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# compute node nova service
#

sudo apt-get -y install neutron-linuxbridge-agent python-oslo.privsep

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

sudo mkdir -p /etc/neutron/plugins/ml2
cat <<EOF | sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini > /dev/null
[linux_bridge]
physical_interface_mappings = provider:enp0s3

[vxlan]
enable_vxlan = false

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

EOF

#
# FIX SUDOERS file
#
sudoers = /etc/sudoers.d/neutron_sudoers
sudo chmod 660 $sudoers
cat <<EOF | sudo tree -a $sudoers > /dev/null
neutron ALL = (root) NOPASSWD: /usr/bin/privsep-helper
neutron ALL = (root) NOPASSWD: /sbin/iptables-save
neutron ALL = (root) NOPASSWD: /sbin/ebtables
EOF
sudo chmod 440 $sudoers

sudo service nova-compute restart
sudo service neutron-linuxbridge-agent restart
