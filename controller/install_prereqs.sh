#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for Ubuntu 18.04 OpenStack skeleton
# all instances will be cloned from this skeleton.
#

#
# Install mariadb
#
# There is a bug in MariaDB 10.1 which is the version which "ships"
# with Ubuntu 18.04. We need at least 10.4 so here we set things
# up so mariadb is installed from mariadb.org.
#
sudo apt-get install software-properties-common
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mirror.netinch.com/pub/mariadb/repo/10.4/ubuntu bionic main'

sudo apt install mariadb-server python-pymysql

cat <<EOF | sudo tee /etc/mysql/mariadb.conf.d/99-openstack.cnf > /dev/null
[mysqld]
bind-address = $IP

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF

sudo service mysql restart
sudo mysql_secure_installation


#
# install rabbit message queue
#
sudo apt install rabbitmq-server
sudo rabbitmqctl add_user openstack RABBIT_PASS
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"

#
# install memcached
#
sudo apt install memcached python-memcache
# fix ip address of listener
sed s/127\\.\\0.\\0\\.1/$IP/ /etc/memcached.conf > /tmp/memcached.conf
sudo cp /tmp/memcached.conf /etc/memcached.conf
rm /tmp/memcached.conf
sudo service memcached restart

#
# install etcd
#
sudo apt install etcd
cat <<EOF | sudo tee /etc/default/etcd > /dev/null
ETCD_NAME="controller"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="controller=http://$IP:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$IP:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$IP:2379"
ETCD_LISTEN_PEER_URLS="http://$IP:2380"
ETCD_LISTEN_CLIENT_URLS="http://$IP:2379"
EOF

sudo systemctl enable etcd
sudo systemctl restart etcd
