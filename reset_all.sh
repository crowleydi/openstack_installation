#!/bin/sh

#
# drops all databases ... be careful!
#
sudo mysql -f <<EOF
drop database cinder;
drop database glance;
drop database keystone;
drop database neutron;
drop database nova;
drop database nova_api;
drop database nova_cell0;
drop database placement;
EOF
