#!/bin/sh

#
# David Crowley
# ECE 530
#
# install script for openstack Minimal deployment for Train
# keystone service

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
drop database keystone;
create database keystone;
grant all privileges on keystone.* to 'keystone'@'localhost' identified by '$KEYSTONE_DBPASS';
grant all privileges on keystone.* to 'keystone'@'%' identified by '$KEYSTONE_DBPASS';
EOF

#
# install the keystone service
#
sudo $APT install keystone

# setup the configuration file
cat <<EOF | sudo tee -a /etc/keystone/keystone.conf > /dev/null
[database]
connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@controller/keystone

[token]
provider = fernet
EOF


# initialize the keystone database
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone

sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

sudo keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne

#
# configure apache
#
cat <<EOF | sudo tee -a /etc/apache2/apache2.conf > /dev/null
ServerName controller
EOF

sudo service apache2 restart

#
# create example domain, demo project, etc.
#
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3

openstack domain create --description "An Example Domain" example
openstack project create --domain default \
  --description "Service Project" service
openstack project create --domain default \
  --description "Demo Project" myproject
openstack user create --domain default \
  --password $DEMO_PASS myuser
openstack role create myrole
openstack role add --project myproject --user myuser myrole

unset OS_AUTH_URL OS_PASSWORD

echo ""
echo ""
echo "Testing keystone authentication. You will be prompted"
echo "to enter passwords for the admin and demo users."
echo ""
echo ""
echo "Enter password for admin user below."
openstack --os-auth-url http://controller:5000/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name admin --os-username admin token issue
echo ""
echo "Enter password for demo user below."
openstack --os-auth-url http://controller:5000/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name myproject --os-username myuser token issue

cat > admin-openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat > demo-openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=myproject
export OS_USERNAME=myuser
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

