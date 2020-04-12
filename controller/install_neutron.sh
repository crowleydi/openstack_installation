#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# neutron service

#
# check that the passwords file has been edited and sourced
#
if [ "$PASSWORDS_SET" != "YES" ]; then
	exit 1;
fi

#
# setup the database table
#
sudo mysql -f <<EOF
drop database neutron;
create database neutron;
grant all privileges on neutron.* to 'neutron'@'localhost' identified by '$NEUTRON_DBPASS';
grant all privileges on neutron.* to 'neutron'@'%' identified by '$NEUTRON_DBPASS';
EOF

. ./admin-openrc

# create service credentials
openstack user create --domain default --password $NEUTRON_PASS neutron
openstack role add --project service --user neutron admin

# create service 
openstack service create --name neutron \
  --description "OpenStack Networking" network

# create endpoints
openstack endpoint create --region RegionOne \
  network public http://controller:9696

openstack endpoint create --region RegionOne \
  network internal http://controller:9696

openstack endpoint create --region RegionOne \
  network admin http://controller:9696


#
# option 1 provider networks
#

#
# install the neutron service components
#

sudo apt-get -y install neutron-server neutron-plugin-ml2 \
  neutron-linuxbridge-agent neutron-dhcp-agent \
  neutron-metadata-agent

cat <<EOF | sudo tee /etc/neutron/neutron.conf > /dev/null
[DEFAULT]
core_plugin = ml2
service_plugins =
transport_url = rabbit://openstack:$RABBIT_PASS@controller
auth_strategy = keystone
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[database]
connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $NEUTRON_PASS

[nova]
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp

EOF

#
# configure the ML2 plug-in
#
cat <<EOF| sudo tee /etc/neutron/plugins/ml2/ml2_conf.ini > /dev/null
[ml2]
type_drivers = flat,vlan
tenant_network_types =
mechanism_drivers = linuxbridge
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[securitygroup]
enable_ipset = true

EOF

#
# configure the linux bridge agent
#
sudo cat <<EOF| sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini > /dev/null
[linux_bridge]
physical_interface_mappings = provider:enp0s3

[vxlan]
enable_vxlan = false

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

EOF

#
# configure the dhcp agent
#
sudo cat <<EOF| sudo tee /etc/neutron/dhcp_agent.ini > /dev/null
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true

EOF

#
# configure the metadata agent
#
sudo cat <<EOF| sudo tee /etc/neutron/metadata_agent.ini > /dev/null
[DEFAULT]
nova_metadata_host = controller
metadata_proxy_shared_secret = $METADATA_SECRET

EOF


#
# finalize the installation
#
# populate the database
sudo su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

# restart the compute service
sudo service nova-api restart

# restart networking services
sudo service neutron-server restart
sudo service neutron-linuxbridge-agent restart
sudo service neutron-dhcp-agent restart
sudo service neutron-metadata-agent restart

#
# verify the service
. ./admin-openrc
openstack extension list --network
