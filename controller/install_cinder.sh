#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# cinder service

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
drop database cinder;
create database cinder;
grant all privileges on cinder.* to 'cinder'@'localhost' identified by '$CINDER_DBPASS';
grant all privileges on cinder.* to 'cinder'@'%' identified by '$CINDER_DBPASS';
EOF

. ./admin-openrc

# create service credentials
openstack user create --domain default --password $CINDER_PASS cinder
openstack role add --project service --user cinder admin

# create service
openstack service create --name cinderv2 \
  --description "Open Block Storage" volumev2

openstack service create --name cinderv3 \
  --description "Open Block Storage" volumev3

# create v2 api endpoints
openstack endpoint create --region RegionOne \
  volumev2 public http://controller:8776/v2/%\(project_id\)s

openstack endpoint create --region RegionOne \
  volumev2 internal http://controller:8776/v2/%\(project_id\)s

openstack endpoint create --region RegionOne \
  volumev2 admin http://controller:8776/v2/%\(project_id\)s

# create v3 api endpoints
openstack endpoint create --region RegionOne \
  volumev3 public http://controller:8776/v3/%\(project_id\)s

openstack endpoint create --region RegionOne \
  volumev3 internal http://controller:8776/v3/%\(project_id\)s

openstack endpoint create --region RegionOne \
  volumev3 admin http://controller:8776/v3/%\(project_id\)s

#
# install components
#
sudo apt-get -y install cinder-api cinder-scheduler

#
# setup the config file
#
cat << EOF | sudo tee /etc/cinder/cinder.conf > /dev/null
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@controller
auth_strategy = keystone
my_ip = $IP

[database]
connection = mysql+pymysql://cinder:$CINDER_DBPASS@controller/cinder

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = cinder
password = $CINDER_PASS

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp

EOF

#
# initialize the database
#
sudo su -s /bin/sh -c "cinder-manage db sync" cinder

#
#  configure compute to use block storage
cat << EOF | sudo tee -a /etc/nova/nova.conf > /dev/null
[cinder]
os_region_name = RegionOne

EOF
#
# restart the compute service
#
sudo service nova-api restart

#
# restart bloack storage services
sudo service cinder-scheduler restart
sudo service apache2 restart
