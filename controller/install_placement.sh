#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# placement service

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
drop database placement;
create database placement;
grant all privileges on placement.* to 'placement'@'localhost' identified by '$PLACEMENT_DBPASS';
grant all privileges on placement.* to 'placement'@'%' identified by '$PLACEMENT_DBPASS';
EOF

. ./admin-openrc

# create service credentials
openstack user create --domain default --password $PLACEMENT_PASS placement
openstack role add --project service --user placement admin

# create service api
openstack service create --name placement \
  --description "Placement API" placement

# create service endpoints
openstack endpoint create --region RegionOne \
  placement public http://controller:8778

openstack endpoint create --region RegionOne \
  placement internal http://controller:8778

openstack endpoint create --region RegionOne \
  placement admin http://controller:8778


#
# install the placement service
#
sudo apt-get -y install placement-api

cat <<EOF | sudo tee /etc/placement/placement.conf > /dev/null
[placement_database]
connection = mysql+pymysql://placement:$PLACEMENT_DBPASS@controller/placement

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
username = glance
password = $PLACEMENT_PASS
EOF

sudo su -s /bin/sh -c "placement-manage db sync" placement

sudo service apache2 restart
