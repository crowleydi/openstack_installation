#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# object node swift service
#

if [ -b "/dev/sdb" ]; then
	echo "found /dev/sdb!"
else
	echo "Must have a /dev/sdb device!"
	exit 1;
fi


# copy the ring files
if [ -e account.ring.gz -a -e container.ring.gz -a -e object.ring.gz ]; then
	sudo cp account.ring.gz container.ring.gz object.ring.gz /etc/swift
else
	echo "Could not find the ring files!"
	exit 1
fi
if [ -e swift.conf ]; then
	sudo cp swift.conf /etc/swift
else
	echo "Could not find swift.conf file!"
	exit 1
fi

#
# pre-requisites

# XFS filesystem is the "best" for this
sudo apt-get -y install xfsprogs rsync
sudo mkfs.xfs /dev/sdb
sudo mkdir -p /srv/node/sdb

# setup fstab
cat <<EOF | sudo tee -a /etc/fstab > /dev/null
/dev/sdb /srv/node/sdb xfs noatime,nodiratime,logbufs=8 0 2
EOF
sudo mount /srv/node/sdc

# setup rsync
cat <<EOF | sudo tee /etc/rsyncd.cond > /dev/null
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $IP

[account]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock
EOF

cat <<EOF | sudo tee -a /etc/rsyncd.cond > /dev/null
RSYNC_ENABLE=true
EOF

# start the rsync service
sudo service rsync start


#
# install the swift packages
sudo apt-get -y install swift swift-account swift-container swift-object

#
# get default configs from opendev.org
sudo curl -o /etc/swift/account-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/account-server.conf-sample
sudo curl -o /etc/swift/container-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/container-server.conf-sample
sudo curl -o /etc/swift/object-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/object-server.conf-sample

#
# edit config files
cat <<EOF | sudo tee -a etc/swift/account-server.conf > /dev/null
[DEFAULT]
bind_ip = $IP
bind_port = 6202
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon account-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
EOF

cat <<EOF | sudo tee -a etc/swift/container-server.conf > /dev/null
[DEFAULT]
bind_ip = $IP
bind_port = 6201
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon container-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

EOF

cat <<EOF | sudo tee -a etc/swift/object-server.conf > /dev/null
[DEFAULT]
bind_ip = $IP
bind_port = 6200
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon object-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
recon_lock_path = /var/lock

EOF

sudo chown -R swift:swift /src/node
sudo mkdir -p /var/cache/swift
sudo chown -R root:swift /var/cache/swift
sudo chmod -R 775 /var/cache/swift

sudo swift-init all start
