#!/bin/bash

# Enable ssh password authentication
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sudo systemctl reload sshd

# Set Root password
sudo echo -e "root\nroot" | passwd root >/dev/null 2>&1
sudo echo 'ansible:ansible' | sudo chpasswd

# Create a ansible user and configure it
sudo useradd -m -s /bin/bash ansible

# Setup SSH directory
sudo mkdir -p /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh

# Add public key
sudo cat /tmp/ansible.pub >> /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys

# Fix ownership
sudo chown -R ansible:ansible /home/ansible/.ssh

sudo echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
sudo chmod 440 /etc/sudoers.d/ansible

sudo mv /tmp/hosts /etc/hosts
sudo chown root:root /etc/hosts
sudo chmod 644 /etc/hosts