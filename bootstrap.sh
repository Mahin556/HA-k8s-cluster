#!/bin/bash

echo "[TASK 1] Install required packages"
apt update -y
apt install -y rsync

# Enable ssh password authentication
echo "[TASK 1] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 2] Create ansible user"

# Create user only if not exists
id -u ansible &>/dev/null || useradd -m -s /bin/bash ansible

# Setup SSH directory
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh

echo "[TASK 3] Configure SSH key authentication"

# Add public key
cat /tmp/ansible.pub >> /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys

# Copy private key
cp /tmp/ansible /home/ansible/.ssh/id_rsa
chmod 600 /home/ansible/.ssh/id_rsa

# Fix ownership
chown -R ansible:ansible /home/ansible/.ssh

echo "[TASK 4] Configure passwordless sudo"

echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

echo "[TASK 5] Configure host resolution"

mv /tmp/hosts /etc/hosts
chown root:root /etc/hosts
chmod 644 /etc/hosts

echo "Bootstrap complete."
