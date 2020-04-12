#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# swift service

#
# check that the passwords file has been edited and sourced
#
if [ "$PASSWORDS_SET" != "YES" ]; then
	exit 1;
fi

. ./admin-openrc

# create service credentials
openstack user create --domain default --password $PLACEMENT_PASS swift
openstack role add --project service --user swift admin

# create service api
openstack service create --name swift \
  --description "OpenStack Object Storage" object-store

# create service endpoints
openstack endpoint create --region RegionOne \
  object-store public http://controller:8080/v1/AUTH_%\(project_id\)s

openstack endpoint create --region RegionOne \
  object-store internal http://controller:8080/v1/AUTH_%\(project_id\)s

openstack endpoint create --region RegionOne \
  object-store admin http://controller:8080/v1


#
# install the placement service
#
sudo apt install swift swift-proxy python-swiftclient \
  python-keystoneclient python-keystonemiddleware \
  memcached

# obtain proxy service config file from Object Storage source repo
sudo curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/proxy-server.conf-sample

cat <<EOF | sudo tee -a /etc/swift/proxy-server.conf > /dev/null
[DEFAULT]
bind_port = 8080
user = swift
swift_dir = /etc/swift

[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
account_autocreate = True

[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = admin,user

[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory

www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = swift
password = $SWIFT_PASS
delay_auth_decision = True

[filter:cache]
use = egg:swift#memcache
memcache_servers = controller:11211

EOF

pushd /etc/swift

#
# create account ring
sudo swift-ring-builder account.builder create 10 3 1
# add the two default hosts
sudo swift-ring-builder account.builder add --region 1 --zone 1 \
   --ip 10.0.0.51 --port 6202 --device sdb --weight 100
sudo swift-ring-builder account.builder add --region 1 --zone 1 \
   --ip 10.0.0.52 --port 6202 --device sdb --weight 100
# verify ring contents
sudo swift-ring-builder account.builder
# rebalance the ring
sudo swift-ring-builder account.builder rebalance

#
# create container ring
sudo swift-ring-builder container.builder create 10 3 1
# add the two default hosts
sudo swift-ring-builder container.builder add --region 1 --zone 1 \
    --ip 10.0.0.51 --port 6201 --device sdb --weight 100
sudo swift-ring-builder container.builder add --region 1 --zone 1 \
    --ip 10.0.0.52 --port 6201 --device sdb --weight 100
# verify ring contents
sudo swift-ring-builder container.builder
# rebalance the ring
sudo swift-ring-builder container.builder rebalance

#
# create object ring
sudo swift-ring-builder object.builder create 10 3 1
# add the two default hosts
sudo swift-ring-builder object.builder add --region 1 --zone 1 \
    --ip 10.0.0.51 --port 6200 --device sdb --weight 100
sudo swift-ring-builder object.builder add --region 1 --zone 1 \
    --ip 10.0.0.52 --port 6200 --device sdb --weight 100
# verify ring contents
sudo swift-ring-builder object.builder
# rebalance the ring
sudo swift-ring-builder object.builder rebalance


popd
#
# finalize
#
# get default swift config from opendev.org
sudo curl -o /etc/swift/swift.conf \
  https://opendev.org/openstack/swift/raw/branch/master/etc/swift.conf-sample
 
#
# setup the config
cat <<EOF | sudo tee -a /etc/swift/swift.conf
[swift-hash]
swift_hash_path_suffix = zxd32
swift_hash_path_prefix = dzx23

[storage-policy:0]
name = Policy-0
default = yes

EOF

cat <<EOF


#####################

You will need to distribute ring configuration files!!!!


Copy the /etc/swift/swift.conf, account.ring.gz, container.ring.gz,
and object.ring.gz files to the openstack_installation directory
of each node before installing swift on that node!

#####################


EOF

sudo chown -R root:swift /etc/swift
sudo service memcached restart
sudo service swift-proxy restart
