#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# block node cinder-backup service
#

if [ -e "/etc/swift/swift.conf" ]; then
	echo "swift appears to be installed!"
else
	echo "Must install swift first."
	exit 1;
fi

#
# install the package
#
sudo apt install cinder-backup

openstack catalog show object-store

echo "Need that url!"
exit 1

cat <<EOF | sudo tee -a /etc/cinder/cinder.conf > /dev/null
[DEFAULT]
backup_driver = cinder.backup.drivers.swift.SwiftBackupDriver
backup_swift_url = SWIFT_URL
EOF

sudo service cinder-backup restart
