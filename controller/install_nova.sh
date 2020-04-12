#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# nova service

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
drop database nova;
create database nova;
grant all privileges on nova.* to 'nova'@'localhost' identified by '$NOVA_DBPASS';
grant all privileges on nova.* to 'nova'@'%' identified by '$NOVA_DBPASS';
drop database nova_api;
create database nova_api;
grant all privileges on nova_api.* to 'nova'@'localhost' identified by '$NOVA_DBPASS';
grant all privileges on nova_api.* to 'nova'@'%' identified by '$NOVA_DBPASS';
drop database nova_cell0;
create database nova_cell0;
grant all privileges on nova_cell0.* to 'nova'@'localhost' identified by '$NOVA_DBPASS';
grant all privileges on nova_cell0.* to 'nova'@'%' identified by '$NOVA_DBPASS';
EOF

. ./admin-openrc

# create service credentials
openstack user create --domain default --password $NOVA_PASS nova
openstack role add --project service --user nova admin

# create service entity
openstack service create --name nova \
  --description "OpenStack Compute" compute

# create service endpoints
openstack endpoint create --region RegionOne \
  compute public http://controller:8774/v2.1

openstack endpoint create --region RegionOne \
  compute internal http://controller:8774/v2.1

openstack endpoint create --region RegionOne \
  compute admin http://controller:8774/v2.1

#
# install the packages
#
sudo apt-get -y install nova-api nova-conductor nova-novncproxy nova-scheduler

#
# configuration
#
cat <<EOF | sudo tee /etc/nova/nova.conf > /dev/null
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@controller:5672/
my_ip = $IP
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[api_database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@controller/nova_api

[database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@controller/nova

[api]
auth_strategy = keystone

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVA_PASS

[vnc]
enabled = true
server_listen = \$my_ip
server_proxyclient_address = \$my_ip

[glance]
api_servers = http://controller:9292

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

EOF

#
# configure the nova compute service to use the
# neutron networking service
sudo cat <<EOF| sudo tee -a /etc/nova/nova.conf > /dev/null
[neutron]
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS
service_metadata_proxy = true
metadata_proxy_shared_secret = $METADATA_SECRET

EOF
sudo su -s /bin/sh -c "nova-manage api_db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
sudo su -s /bin/sh -c "nova-manage db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova

sudo service nova-api restart
sudo service nova-scheduler restart
sudo service nova-conductor restart
sudo service nova-novncproxy restart
sudo service neutron-linuxbridge-agent restart

openstack compute service list --service nova-compute
