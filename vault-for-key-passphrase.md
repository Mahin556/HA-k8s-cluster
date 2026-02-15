```bash
==================== ANSIBLE VAULT IDENTITY SETUP ====================

# Directory structure for multi-environment vault setup
k8s-cluster-ansible/
├── ansible.cfg
├── .vault_dev          # Dev vault password file
├── .vault_stage        # Staging vault password file
├── .vault_prod         # Production vault password file
├── inventory/
│   ├── dev/
│   ├── staging/
│   └── production/


# Create password files for each environment
# These files contain only the vault password
echo "DevPassword123" > .vault_dev
echo "StagePassword123" > .vault_stage
echo "ProdPassword123" > .vault_prod

# Secure password files (required for security)
chmod 600 .vault_*


# Configure vault identities inside ansible.cfg
# This maps environment name → password file
[defaults]
inventory = inventory/production/hosts.ini
vault_identity_list = dev@.vault_dev,stage@.vault_stage,prod@.vault_prod


# Create encrypted vault variable files per environment
# --encrypt-vault-id ensures the correct identity is embedded
ansible-vault create inventory/dev/group_vars/all/vault.yml --encrypt-vault-id dev
ansible-vault create inventory/staging/group_vars/all/vault.yml --encrypt-vault-id stage
ansible-vault create inventory/production/group_vars/all/vault.yml --encrypt-vault-id prod


# IMPORTANT:
# In real projects, .vault_dev / .vault_stage / .vault_prod
# are NOT committed to Git for security reasons.


# Alternative method (recommended for production or CI/CD):
# Use environment variable instead of storing password file locally
export ANSIBLE_VAULT_IDENTITY_LIST="prod@/secure/path/prod_pass"


# Run playbooks normally (no extra vault flags required)
ansible-playbook -i inventory/dev/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/staging/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/production/hosts.ini playbooks/site.yml



==================== HOW AUTO-DECRYPT WORKS ====================

# 1) vault_identity_list defines identity → password mapping
#    dev   → .vault_dev
#    stage → .vault_stage
#    prod  → .vault_prod


# 2) When playbook runs for production:
ansible-playbook -i inventory/production/hosts.ini playbooks/site.yml


# 3) Ansible automatically:
#    ✔ Loads encrypted vault.yml
#    ✔ Reads first line of file:
#      $ANSIBLE_VAULT;1.2;AES256;prod
#    ✔ Detects vault ID = prod
#    ✔ Matches prod → .vault_prod
#    ✔ Uses correct password file
#    ✔ Decrypts variables in memory
#    ✔ Executes playbook normally


# 4) No need for:
#    ❌ --ask-vault-pass
#    ❌ --vault-password-file
#    ❌ --encrypt-vault-id (during runtime)


# 5) Auto-decrypt works IF:
#    ✔ vault_identity_list is configured
#    ✔ Encrypted file contains correct vault ID
#    ✔ Password file exists
#    ✔ File permissions are secure (chmod 600)


# RESULT:
# Ansible automatically selects the correct password
# and decrypts secrets in memory during execution.
```