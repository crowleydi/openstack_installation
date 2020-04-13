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
openstack user create --domain default --password $SWIFT_PASS swift
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
# install the swift packages
#
sudo apt-get -y install swift swift-proxy python-swiftclient \
  python-keystoneclient python-keystonemiddleware \
  memcached

# get default swift config from opendev.org
sudo mkdir -p /etc/swift
sudo curl -o /etc/swift/swift.conf-sample \
  https://opendev.org/openstack/swift/raw/branch/master/etc/swift.conf-sample
 
#
# setup the config
cat <<EOF | sudo tee /etc/swift/swift.conf > /dev/null
[swift-hash]
swift_hash_path_suffix = zxd32
swift_hash_path_prefix = dzx23

[storage-policy:0]
name = Policy-0
default = yes
aliases = yellow, orange

EOF

# obtain proxy service config file from Object Storage source repo
sudo curl -o /etc/swift/proxy-server.conf-sample https://opendev.org/openstack/swift/raw/branch/master/etc/proxy-server.conf-sample

# setup the proxy config
cat <<EOF | sudo tee /etc/swift/proxy-server.conf > /dev/null
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

[filter:s3api]
use = egg:swift#s3api

[filter:s3token]
use = egg:swift#s3token
reseller_prefix = AUTH_
delay_auth_decision = False
auth_uri = http://keystonehost:5000/v3
http_timeout = 10.0

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:ratelimit]
use = egg:swift#ratelimit

[filter:read_only]
use = egg:swift#read_only

[filter:domain_remap]
use = egg:swift#domain_remap

[filter:catch_errors]
use = egg:swift#catch_errors

[filter:cname_lookup]
use = egg:swift#cname_lookup

[filter:staticweb]
use = egg:swift#staticweb

[filter:formpost]
use = egg:swift#formpost

[filter:name_check]
use = egg:swift#name_check

[filter:etag-quoter]
use = egg:swift#etag_quoter

[filter:list-endpoints]
use = egg:swift#list_endpoints

[filter:proxy-logging]
use = egg:swift#proxy_logging

[filter:bulk]
use = egg:swift#bulk

[filter:slo]
use = egg:swift#slo

[filter:dlo]
use = egg:swift#dlo

[filter:container-quotas]
use = egg:swift#container_quotas

[filter:account-quotas]
use = egg:swift#account_quotas

[filter:gatekeeper]
use = egg:swift#gatekeeper

[filter:container_sync]
use = egg:swift#container_sync

[filter:xprofile]
use = egg:swift#xprofile

[filter:versioned_writes]
use = egg:swift#versioned_writes

[filter:copy]
use = egg:swift#copy

[filter:keymaster]
use = egg:swift#keymaster
encryption_root_secret = changeme

[filter:kms_keymaster]
use = egg:swift#kms_keymaster

[filter:kmip_keymaster]
use = egg:swift#kmip_keymaster

[filter:encryption]
use = egg:swift#encryption

[filter:listing_formats]
use = egg:swift#listing_formats

[filter:symlink]
use = egg:swift#symlink

EOF

_pushd=`pwd`
cd /etc/swift

#
# create account ring
sudo swift-ring-builder account.builder create 10 2 1
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
sudo swift-ring-builder container.builder create 10 2 1
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
sudo swift-ring-builder object.builder create 10 2 1
# add the two default hosts
sudo swift-ring-builder object.builder add --region 1 --zone 1 \
    --ip 10.0.0.51 --port 6200 --device sdb --weight 100
sudo swift-ring-builder object.builder add --region 1 --zone 1 \
    --ip 10.0.0.52 --port 6200 --device sdb --weight 100
# verify ring contents
sudo swift-ring-builder object.builder
# rebalance the ring
sudo swift-ring-builder object.builder rebalance

cd $_pushd

#
# finalize
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
