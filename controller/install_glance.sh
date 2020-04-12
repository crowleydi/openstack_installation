#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# glance service

#
# check that the passwords file has been edited and sourced
#
if [ "$PASSWORDS_SET" != "YES" ]; then
	exit 1;
fi

#
# create the database
#
sudo mysql -f <<EOF
drop database glance;
create database glance;
grant all privileges on glance.* to 'glance'@'localhost' identified by '$GLANCE_DBPASS';
grant all privileges on glance.* to 'glance'@'%' identified by '$GLANCE_DBPASS';
EOF

. ./admin-openrc

# create service credentials
openstack user create --domain default --password $GLANCE_PASS glance
openstack role add --project service --user glance admin

# create service
openstack service create --name glance \
  --description "OpenStack Image" image

# create api endpoints
openstack endpoint create --region RegionOne \
  image public http://controller:9292

openstack endpoint create --region RegionOne \
  image internal http://controller:9292

openstack endpoint create --region RegionOne \
  image admin http://controller:9292


#
# install the glance service
#
sudo apt-get -y install glance

#
# setup the config file
#
cat << EOF | sudo tee /etc/glance/glance-api.conf > /dev/null
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $GLANCE_PASS

[paste_deploy]
flavor = keystone

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images
EOF

#
# initialize the database
#
sudo su -s /bin/sh -c "glance-manage db_sync" glance

#
# restart the service
#
sudo service glance-api restart
