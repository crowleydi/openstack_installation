# openstack_installation

## ECE 530 Cloud Computing
## Homework 1

This is a collection of script files written to automate
the installation of OpenStack Train on Ubuntu 18.04.4

The commands executed come from the following document:

https://docs.openstack.org/install-guide/openstack-services.html#minimal-deployment-for-train

I have made a few small changes to help with automation and to fix
any problems encountered.


### Controller install

I have a skeleton VM setup on Virtual Box which has
these Ubuntu 18.04.4 installed and this scripts.

Make a clone of the skeleton vm and name it "Controller".
The first step is to run the script `fix_net.sh` like this:

```
./fix_net controller 10.0.0.11
```

This command will set the hostname to `controller`, configure
`/etc/hosts` with some default hostnames, and fix up
`/etc/netplan/cloud-init.yaml` to set the adapter to the given
ip address and reboots the machine.

Login to the controller and then run the following command to install
some initial packages.

```
./setup_prereq.sh
```

After the above packages have installed, edit the install.sh file
to set password preferences.

Individual components can be installed with a command like the following:

```
./install.sh keystone controller
```

This will download and install the openstack packages for keystone
and configure it according to the default example OpenStack architecture.
Other individual packages can be installed this way as well. All packages
for the minimal installation can be installed like this:

```
./install.sh minimal controller
```

### Compute node install

Make another clone of the skel VM, login and run the following command:

```
./fix_net compute1 10.0.0.31
```

This will set the hostname and ipaddress and reboot the machine.
When the machine comes backup, you can install the compute service
with this command:

```
./install.sh nova node
```
