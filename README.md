```bash
# On server1
vagrant up masterone mastertwo masterthree

# On server2
vagrant up etcdone etcdtwo etcdthree
vagrant up workerone lbone lbtwo
```

```bash
# On server1
vagrant halt masterone mastertwo masterthree

# On server2
vagrant halt etcdone etcdtwo etcdthree
vagrant halt workerone lbone lbtwo
```

```bash
# On server1
vagrant destroy masterone mastertwo masterthree

# On server2
vagrant destroy etcdone etcdtwo etcdthree
vagrant destroy workerone lbone lbtwo
```
```bash
$ ssh-keygen -t ed25519 -b 4096

Generating public/private ed25519 key pair.
Enter file in which to save the key (/root/.ssh/id_ed25519): /root/.ssh/ansible   
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/ansible
Your public key has been saved in /root/.ssh/ansible.pub
```
```bash
$ eval $(ssh-agent)
Agent pid 3038

$ ssh-add /root/.ssh/ansible
Enter passphrase for /root/.ssh/ansible: 
Identity added: /root/.ssh/ansible (root@SVM)

$ ssh-add -l
256 SHA256:UDNgYrArbAGnssz9vyUXa1NZKLmG26eGYAefy67auCk root@SVM (ED25519)

$ ssh -A node
```
```bash
export ANSIBLE_CONFIG=~/HA-k8s-cluster/k8s-cluster-ansible/ansible.cfg

ansible-galaxy collection install -r collections/requirements.yml -p ~/HA-k8s-cluster/k8s-cluster-ansible/collections/

```
```bash
k8s-cluster-ansible/
├── ansible.cfg
├── .vault_dev
├── .vault_stage
├── .vault_prod
├── inventory/
│   ├── dev/
│   ├── staging/
│   └── production/

echo "DevPassword123" > .vault_dev
echo "StagePassword123" > .vault_stage
echo "ProdPassword123" > .vault_prod
chmod 600 .vault_*

[defaults]
inventory = inventory/production/hosts.ini
vault_identity_list = dev@.vault_dev,stage@.vault_stage,prod@.vault_prod

ansible-vault create inventory/dev/group_vars/all/vault.yml --encrypt-vault-id dev
ansible-vault create inventory/staging/group_vars/all/vault.yml --encrypt-vault-id stage
ansible-vault create inventory/production/group_vars/all/vault.yml --encrypt-vault-id prod

#They do NOT store .vault_dev in project.
export ANSIBLE_VAULT_IDENTITY_LIST="prod@/secure/path/prod_pass"
#Or CI/CD injects it.

ansible-playbook -i inventory/dev/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/staging/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/production/hosts.ini playbooks/site.yml
```
```bash
✅ HOW VAULT IDENTITY AUTO-DECRYPT WORKS

1) In ansible.cfg:

   vault_identity_list = dev@.vault_dev,stage@.vault_stage,prod@.vault_prod

   This means:
   - dev   → use .vault_dev
   - stage → use .vault_stage
   - prod  → use .vault_prod


2) When you run:

   ansible-playbook -i inventory/production/hosts.ini playbooks/site.yml


3) Ansible does this automatically:

   ✔ Loads vault.yml from production inventory
   ✔ Reads first line of encrypted file:
     
     $ANSIBLE_VAULT;1.2;AES256;prod

   ✔ Sees vault ID = prod
   ✔ Matches it with:
     
     prod@.vault_prod

   ✔ Uses .vault_prod password
   ✔ Decrypts file in memory
   ✔ Uses variables normally


4) You DO NOT need:

   ❌ --ask-vault-pass
   ❌ --vault-password-file
   ❌ --encrypt-vault-id (during playbook run)


5) It works automatically IF:

   ✔ vault_identity_list is configured
   ✔ vault file has correct vault ID
   ✔ password file exists
   ✔ permissions are correct (chmod 600)


Result:
Ansible automatically selects the correct password
and decrypts the variables in memory at runtime.
```

---

## **Vagrant Environment**

| Role          | FQDN                    | IP            | OS           | RAM | CPU |
| ------------- | ----------------------- | ------------- | ------------ | --- | --- |
| Etcd 1        | etcdone.example.com     | 192.168.29.61 | Ubuntu 22.04 | 1G  | 1   |
| Etcd 2        | etcdtwo.example.com     | 192.168.29.62 | Ubuntu 22.04 | 1G  | 1   |
| Etcd 3        | etcdthree.example.com   | 192.168.29.63 | Ubuntu 22.04 | 1G  | 1   |
| Master 1      | masterone.example.com   | 192.168.29.51 | Ubuntu 22.04 | 2G  | 2   |
| Master 2      | mastertwo.example.com   | 192.168.29.52 | Ubuntu 22.04 | 2G  | 2   |
| Master 3      | masterthree.example.com | 192.168.29.53 | Ubuntu 22.04 | 2G  | 2   |
| Load Balancer | lbone.example.com       | 192.168.29.81 | Ubuntu 22.04 | 1G  | 1   |
| Load Balancer | lbtwo.example.com       | 192.168.29.82 | Ubuntu 22.04 | 1G  | 1   |
| Worker 1      | workerone.example.com   | 192.168.29.71 | Ubuntu 22.04 | 1G  | 1   |
---
![](/Untitled%20design.gif)
---

## **Virtual IP (VIP)**

| Purpose            | IP                |
| ------------------ | ----------------- |
| Kubernetes API VIP | **192.168.29.80** |

The VIP is managed by **Keepalived** and floats between `lbone` and `lbtwo`.

---

## **Architecture Overview**

This lab represents a **production-style highly available Kubernetes architecture** demonstrating how **external etcd**, **multiple control-plane nodes**, and **redundant load balancers** work together using **TLS and quorum-based safety**.

The design avoids **all single points of failure**, including the Kubernetes API endpoint.

---

## **etcd Cluster**

There are **three etcd nodes**, each running on its own machine. Together they form a **highly available etcd cluster** responsible for storing **all Kubernetes state**, including:

* Cluster metadata
* Pod and node information
* Secrets and ConfigMaps
* RBAC rules
* Leader election data

etcd uses the **Raft consensus protocol** and requires a **quorum of 2 out of 3 nodes** to accept writes.

Each etcd node has:

* Its **own unique TLS certificate and private key**
* Certificates signed by a **single shared etcd CA**

This ensures:

* Encrypted communication
* Strong identity verification
* No split-brain
* Clear peer authentication

Using **unique certificates per etcd node with a shared CA** is **standard and recommended practice**.

---

## **Load Balancers (HAProxy + Keepalived)**

There are **two load balancer nodes**:

* `lbone.example.com`
* `lbtwo.example.com`

Both run:

* **HAProxy** → load balances traffic to masters
* **Keepalived** → manages a floating **Virtual IP (VIP)**

### API Entry Point

```
192.168.29.80:6443
```

Key properties:

* Only **one LB owns the VIP at a time**
* If the active LB fails, the VIP automatically moves to the standby LB
* kubeadm, kubelets, and kubectl **always use the VIP**, never a node IP

This guarantees:

* API availability during LB failure
* No client reconfiguration
* Seamless failover

---

## **Control Plane (Masters)**

There are **three master nodes**, forming a **highly available control plane**.

Each master runs:

* kube-apiserver
* kube-controller-manager
* kube-scheduler

Important characteristics:

* Masters **do not store cluster state locally**
* All state is stored in **external etcd**
* kube-apiserver connects to etcd over **HTTPS**

### etcd Client Authentication

All kube-apiserver instances:

* Use the **same etcd client certificate**

  * `apiserver-etcd-client.pem`
* Trust the same etcd CA

This is:

* kubeadm-compliant
* Secure (client-only cert)
* Common in production clusters
* Easier to manage operationally

The certificate is scoped only for **client authentication** and **cannot act as an etcd server or peer**.

---

## **Worker Node**

There is **one worker node** responsible for running workloads.

The worker node:

* Never communicates with etcd
* Talks only to the Kubernetes API via the **VIP**
* Relies entirely on the control plane for scheduling and state

This enforces a clean separation between:

* **Cluster control**
* **Application execution**
* **Data storage**

---

## **Security Model**

The cluster uses **mutual TLS (mTLS)** throughout.

Trust hierarchy:

* One **etcd CA** (root of trust)
* Unique TLS certificates for each etcd node
* Shared client certificate for kube-apiserver
* Encrypted communication everywhere

Responsibility separation:

* **etcd** → durable, consistent data store
* **Load balancers** → highly available API entry
* **Control plane** → orchestration and scheduling
* **Workers** → workload execution only

---

## **Why this architecture is correct**

* No single point of failure
* Quorum-protected state changes
* API endpoint survives node failures
* Matches kubeadm HA topology recommendations
* Mirrors real-world Kubernetes deployments

---

## **References**

* [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)
* [https://github.com/cloudflare/cfssl](https://github.com/cloudflare/cfssl)
* [https://github.com/justmeandopensource/kubernetes](https://github.com/justmeandopensource/kubernetes)
* [https://github.com/networknuts/kubernetes](https://github.com/networknuts/kubernetes)
* [https://youtu.be/YUrAXr5MJ0c](https://youtu.be/YUrAXr5MJ0c)
* [https://youtu.be/dGUAanaYr8o](https://youtu.be/dGUAanaYr8o)
* [https://youtu.be/Apwbp4-CZno](https://youtu.be/Apwbp4-CZno)
* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/
