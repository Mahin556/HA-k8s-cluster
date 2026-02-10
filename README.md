```bash
# On server1
vagrant up masterone mastertwo masterthree

# On server2
vagrant up etcdone etcdtwo etcdthree
vagrant up workerone lbone
```
```bash
# On server1
vagrant halt masterone mastertwo masterthree

# On server2
vagrant halt etcdone etcdtwo etcdthree
vagrant halt workerone lbone
```
```bash
# On server1
vagrant destroy masterone mastertwo masterthree

# On server2
vagrant destroy etcdone etcdtwo etcdthree
vagrant destroy workerone lbone
```

---

### **Vagrant Environment**

| Role          | FQDN                    | IP            | OS           | RAM | CPU |
| ------------- | ----------------------- | ------------- | ------------ | --- | --- |
| Etcd 1        | etcdone.example.com     | 192.168.29.61 | Ubuntu 22.04 | 1G  | 1   |
| Etcd 2        | etcdtwo.example.com     | 192.168.29.62 | Ubuntu 22.04 | 1G  | 1   |
| Etcd 3        | etcdthree.example.com   | 192.168.29.63 | Ubuntu 22.04 | 1G  | 1   |
| Master 1      | masterone.example.com   | 192.168.29.51 | Ubuntu 22.04 | 2G  | 2   |
| Master 2      | mastertwo.example.com   | 192.168.29.52 | Ubuntu 22.04 | 2G  | 2   |
| Master 3      | masterthree.example.com | 192.168.29.53 | Ubuntu 22.04 | 2G  | 2   |
| Load Balancer | lb.example.com          | 192.168.29.81 | Ubuntu 22.04 | 1G  | 1   |
| Worker 1      | workerone.example.com   | 192.168.29.71 | Ubuntu 22.04 | 1G  | 1   |

---

#### **Architecture Overview**

This lab is a clean, production-style Kubernetes setup designed to clearly demonstrate how **external etcd, a highly available control plane, and TLS-based security** work together.

---

#### **etcd Cluster**

There are **three etcd nodes**, each running on a separate machine. Together, they form a **highly available etcd cluster** that stores all Kubernetes state data, including cluster metadata, configuration, secrets, and object definitions.

The etcd nodes communicate with each other using the **Raft consensus protocol** and require a quorum (2 out of 3 nodes) to remain healthy and operational.

Each etcd node has:

* Its **own unique TLS certificate and private key**
* Certificates signed by a **single shared etcd Certificate Authority (CA)**

This design ensures:

* Strong identity verification between etcd peers
* Encrypted peer-to-peer and client traffic
* Clear separation of node identities

Using different certificates per etcd node while trusting a common CA is **standard and recommended practice**, even in production environments.

---

#### **Load Balancer**

A **dedicated load balancer (HAProxy)** runs on a separate node and exposes a single stable endpoint:

```
192.168.29.81:6443
```

All Kubernetes API traffic flows through this load balancer. It forwards requests to the active control-plane nodes and enables:

* High availability
* Seamless failover
* A single, stable API endpoint for all clients and nodes

---

#### **Control Plane (Masters)**

There are **three master nodes** forming a **highly available Kubernetes control plane**. Each master runs:

* kube-apiserver
* kube-controller-manager
* kube-scheduler

The master nodes **do not store any cluster data locally**. Instead, all state is stored in the external etcd cluster.

All kube-apiserver instances:

* Connect to etcd over HTTPS
* Use the **same etcd client certificate** (`apiserver-etcd-client.pem`)
* Trust the same etcd CA

Using a **single shared client certificate** for all API servers is:

* kubeadm-compliant
* Secure
* Operationally simple
* Common in real-world Kubernetes deployments

This certificate is scoped strictly for **client authentication** and cannot be used to act as an etcd server or peer.

---

#### **Worker Node**

There is **one worker node** responsible for running application workloads.

The worker node:

* Never communicates with etcd directly
* Talks only to the Kubernetes API via the load balancer
* Relies on the control plane to read/write cluster state on its behalf

This design ensures strong isolation between application workloads and the cluster’s data store.

---

#### **Security Model**

The entire infrastructure is secured using **mutual TLS (mTLS)** with a clear trust hierarchy:

* A single **etcd CA** acts as the root of trust
* Each etcd node has a unique server/peer certificate
* All kube-apiserver instances share one etcd client certificate
* All communication with etcd is encrypted and authenticated

Responsibilities are cleanly separated:

* **etcd** → stores and protects cluster data
* **Load balancer** → provides a stable and highly available API endpoint
* **Control plane** → manages cluster state and scheduling
* **Worker nodes** → run applications only

This lab closely mirrors **real-world, production-grade Kubernetes architectures** while remaining simple enough for learning and experimentation.

---

### Reference:-
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/
- https://github.com/cloudflare/cfssl
- https://youtu.be/YUrAXr5MJ0c?si=qhyMs1eB_43qLDDX
- https://youtu.be/TLDhHvJOGi8?si=rOq9uDNn5ofNAhdB
- https://youtu.be/dQ5zsJEX47s?si=w0XuyDmEnP01mIPg
- https://youtu.be/gYNEUC9paW8?si=2Zy6dMzL4p81vj8a
- https://github.com/networknuts/kubernetes/blob/master/scripts/cluster-setup-manager-1.35.txt
- https://github.com/networknuts/kubernetes/blob/master/scripts/cluster-setup-node-1.35.txt
- https://github.com/networknuts/kubernetes/blob/master/ch-10-high-value-extra/etcd-cluster-understanding
- https://youtu.be/Apwbp4-CZno?si=QAjPj6KG944inyWJ
- https://youtu.be/1huWcFuESYg?si=CLjKU7uuMunYFTgG
- https://github.com/justmeandopensource/kubernetes/blob/master/kubeadm-external-etcd/3%20setup-kubernetes-with-external-etcd.md