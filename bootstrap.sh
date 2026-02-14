#!/bin/bash

echo "[TASK 1] Install required packages"
sudo apt update -y
sudo apt install -y rsync

# Enable ssh password authentication
echo "[TASK 1] Enable ssh password authentication"
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sudo systemctl reload sshd

echo "[TASK 2] Create ansible user"

# Create user only if not exists
sudo id -u ansible &>/dev/null || useradd -m -s /bin/bash ansible

# Setup SSH directory
sudo mkdir -p /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh

echo "[TASK 3] Configure SSH key authentication"

# Add public key
sudo cat /tmp/ansible.pub >> /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys

# Copy private key
sudo cp /tmp/ansible /home/ansible/.ssh/id_rsa
chmod 600 /home/ansible/.ssh/id_rsa

# Fix ownership
sudo chown -R ansible:ansible /home/ansible/.ssh

echo "[TASK 4] Configure passwordless sudo"

echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
sudo chmod 440 /etc/sudoers.d/ansible

echo "[TASK 5] Configure host resolution"

sudo mv /tmp/hosts /etc/hosts
sudo chown root:root /etc/hosts
sudo chmod 644 /etc/hosts

echo "Bootstrap complete."
