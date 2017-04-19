#!/bin/bash

# Name the CentOS 7 template.
TEMPLATE='centos7-master'

# Gluster nodes.
DOMS="gclient"


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
    echo "$dom has valid IP= $ip"
done


# Extract the clones IP addresses and create an inventory file.
echo "[gcli:vars]
ansible_ssh_user=root
domain=example.com

[gcli]" > gcli.inventory

for dom in $DOMS ; do
    ip=$(sudo virsh domifaddr $dom | grep ipv4 | sed -e's/  */ /g' | cut -d' ' -f5 | cut -d/ -f1)
    echo "$ip hostname=$dom" >> gcli.inventory

    # Clean up known_hosts
    ssh-keygen -R $ip

    # Copy SSH key to host.
    ssh-copy-id -o StrictHostKeyChecking=no -i $HOME/.ssh/id_rsa.pub root@${ip}
done

# Testing the connection.
ansible -i gcli.inventory gcli -m ping

echo "

Looks good? Now execute:

ansible-playbook -i gcli.inventory client.yaml

"
