```bash
# On server1
vagrant up masterone

# On server2
vagrant up etcdone etcdtwo etcdthree
vagrant up workerone
```
```bash
# On server1
vagrant halt masterone

# On server2
vagrant halt etcdone etcdtwo etcdthree
vagrant halt workerone
```
```bash
# On server1
vagrant destroy masterone

# On server2
vagrant destroy etcdone etcdtwo etcdthree
vagrant destroy workerone
```
---

### Vagrant Environment

|Role|FQDN|IP|OS|RAM|CPU|
|----|----|----|----|----|----|
|Etcd 1|etcdone.example.com|192.168.29.61|Ubuntu 22.04|1G|1|
|Etcd 2|etcdtwo.example.com|192.168.29.62|Ubuntu 22.04|1G|1|
|Etcd 3|etcdthree.example.com|192.168.29.63|Ubuntu 22.04|1G|1|
|Master|masterone.example.com|192.168.29.51|Ubuntu 22.04|2G|2|
|Worker|workerone.example.com|192.168.29.71|Ubuntu 22.04|1G|1|

---

This lab is a small, clean Kubernetes setup designed to clearly demonstrate how **OpenSSL-based PKI enables secure communication between etcd and the Kubernetes control plane**.

A **single Certificate Authority (CA)** is created using OpenSSL. This CA acts as the **root of trust** for the entire infrastructure. All certificates used by etcd and the Kubernetes API server are **signed by this CA**, allowing mutual TLS (mTLS) authentication.

There are **three etcd nodes**, each running on a separate machine.
Each etcd node has:

* Its **own private key**
* Its **own X.509 certificate** generated with OpenSSL
* Certificates containing **unique SANs (IP + DNS name)**

Although the certificates are different for every etcd node, they are all signed by the **same etcd CA**, which is a common and acceptable practice for lab and production environments. The etcd nodes authenticate each other using **mutual TLS**, and all peer-to-peer communication is encrypted. Internally, the etcd cluster uses the **Raft consensus protocol**, requiring a majority (2 out of 3) of members to remain available.

There is **one master node** running the Kubernetes control plane components.
The master node **does not store any cluster data locally**. Instead, the kube-apiserver connects to the external etcd cluster over HTTPS using **client certificate authentication**.

For this purpose, a **dedicated client certificate** is generated using OpenSSL:

* `apiserver-etcd-client.pem`
* `apiserver-etcd-client-key.pem`

This certificate is also signed by the same etcd CA but is scoped specifically for **client authentication**, not server or peer communication. This separation ensures that the API server can authenticate itself to etcd without being able to act as an etcd peer.

There is **one worker node** that runs application workloads.
The worker node **never communicates with etcd directly** and therefore does not require any etcd certificates. Instead, it communicates only with the kube-apiserver using Kubernetes-issued credentials. Any request that affects cluster state is forwarded by the API server to etcd using its client certificate.

Overall, the infrastructure demonstrates a clear **PKI trust model using OpenSSL**:

* The **CA establishes trust**
* **etcd server and peer certificates** secure internal cluster communication
* The **API server client certificate** provides controlled access to etcd
* The **worker node remains isolated from etcd**

This design cleanly separates responsibilities while enforcing strong cryptographic identity and encrypted communication across all components.

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