#!/bin/sh
# must change this to YES once appropriate passwords have been selected
export PASSWORDS_SET=NO

export ADMIN_PASS=ADMIN_PASS
export CINDER_DBPASS=CINDER_DBPASS
export CINDER_PASS=CINDER_PASS
export DASH_DBPASS=DASH_DBPASS
export DEMO_PASS=DEMO_PASS
export GLANCE_DBPASS=GLANCE_DBPASS
export GLANCE_PASS=GLANCE_PASS
export KEYSTONE_DBPASS=KEYSTONE_DBPASS
export NEUTRON_DBPASS=NEUTRON_DBPASS
export NEUTRON_PASS=NEUTRON_PASS
export NOVA_DBPASS=NOVA_DBPASS
export NOVA_PASS=NOVA_PASS
export PLACEMENT_PASS=PLACEMENT_PASS
export RABBIT_PASS=RABBIT_PASS
export SWIFT_PASS=SWIFT_PASS

export METADATA_SECRET=METADATA_SECRET

# set management interface
export MANAGEMENT_INTERFACE=enp0s3

# figure out the ip address of the network interface
export IP=`ifconfig $MANAGEMENT_INTERFACE | awk '/inet /{print $2}'`

if [ "$PASSWORDS_SET" != "YES" ]; then
	echo Must setup passwords!
	exit 1;
fi

if [ -z "$1" -o -z "$2" ]; then 
	echo "Must specify service and compute/node"
	echo "usage: $1 [servicename] [controller|node]"
	exit 1
fi

if [ "$2" != "controller" -a "$2" != "node" ]; then
	echo "invalid node type: $2"
	exit 1
fi

if [ "$1" = "minimal" -a "$2" = "controller" ]; then
	./controller/install_prereqs.sh
	./controller/install_keystone.sh
	./controller/install_glance.sh
	./controller/install_placement.sh
	./controller/install_nova.sh
	./controller/install_neutron.sh
	./controller/install_horizon.sh
	./controller/install_cinder.sh
else
	./"$2"/install_"$1".sh
fi
