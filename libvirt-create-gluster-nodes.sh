#!/bin/bash

# Name the CentOS 7 template.
TEMPLATE='centos7-master'

# Gluster nodes.
DOMS="gluster1 gluster2 gluster3"

# Check if it is a valid template.
#tmp=$(virsh dominfo $TEMPLATE)
#if [ $tmp !~ 'Domain not found' ] ; then
#    echo "Invalid template name. Exiting!"
#    exit -1
#fi

# Install requisites.
sudo dnf install -y ansible libvirt-client virt-install


# Create the clones.
for dom in $DOMS ; do
    sudo virt-clone -o $TEMPLATE -n $dom --auto-clone
done


# Start the clones.
for dom in $DOMS ; do
    sudo virsh start $dom
done


# Make sure IPS are valid.
for dom in $DOMS ; do
    echo "Waiting for $dom IP address."
    ip=""
    while [ "$ip" == "" ] ; do
	echo -n "."
	sleep 1
	ip=$(sudo virsh domifaddr $dom | grep ipv4 | sed -e's/  */ /g' | cut -d' ' -f5 | cut -d/ -f1)
    done
    echo "$dom has valid IP."
done


# Create and attach a second disk for bricks.
# NOTE: It is important to attach the second disk after the vm has started so the system disk aquires the slot "vda".
for dom in $DOMS ; do
    sudo virsh vol-create-as default ${dom}-brick1.qcow2 10G --format qcow2 --prealloc-metadata
    sudo virsh attach-disk $dom --source /var/lib/libvirt/images/${dom}-brick1.qcow2 --target vdb --persistent
done


# Extract the clones IP addresses and create an inventory file.
echo "[gluster:vars]
ansible_ssh_user=root
domain=example.com

[gluster]" > gluster.inventory

for dom in $DOMS ; do
    ip=$(sudo virsh domifaddr $dom | grep ipv4 | sed -e's/  */ /g' | cut -d' ' -f5 | cut -d/ -f1)
    echo "$ip hostname=$dom" >> gluster.inventory

    # Clean up known_hosts
    ssh-keygen -R $ip

    # Copy SSH key to host.
    ssh-copy-id -o StrictHostKeyChecking=no -i $HOME/.ssh/id_rsa.pub root@${ip}
done

# Testing the connection.
ansible -i gluster.inventory gluster -m ping

echo "

Looks good? Now execute:

ansible-playbook -i gluster.inventory gluster.yaml

"
