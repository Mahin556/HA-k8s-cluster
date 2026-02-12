#!/bin/bash

# Enable ssh password authentication
echo "[TASK 1] Enable ssh password authentication"
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sudo systemctl reload sshd

# Set Root password
echo "[TASK 2] Set root password"
sudo echo -e "root\nroot" | passwd root >/dev/null 2>&1

# Create a ansible user and configure it
sudo useradd -m -s /bin/bash ansible
sudo mkdir -p /home/ansible/.ssh
sudo cat /tmp/ansible.pub >> /home/ansible/.ssh/authorized_keys
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

sudo mv /tmp/hosts /etc/hosts
sudo chown root:root /etc/hosts
sudo chmod 644 /etc/hosts