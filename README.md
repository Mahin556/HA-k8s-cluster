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

### Vagrant Environment

|Role|FQDN|IP|OS|RAM|CPU|
|----|----|----|----|----|----|
|Etcd 1|etcdone.example.com|192.168.29.61|Ubuntu 22.04|1G|1|
|Etcd 2|etcdtwo.example.com|192.168.29.62|Ubuntu 22.04|1G|1|
|Etcd 3|etcdthree.example.com|192.168.29.63|Ubuntu 22.04|1G|1|
|Master|masterone.example.com|192.168.29.51|Ubuntu 22.04|2G|2|
|Worker|workerone.example.com|192.168.29.71|Ubuntu 22.04|1G|1|

This lab is a small, clean Kubernetes setup designed to clearly show how **etcd and the control plane work together**.

There are **three etcd nodes** running on separate machines. Together they form an **etcd cluster** that stores all Kubernetes data such as cluster state, pod information, and configuration. The etcd nodes communicate with each other using the Raft protocol and require a majority (2 out of 3) to stay healthy. All etcd nodes use the **Differente TLS certificate and key**, signed by a single **etcd CA**, which is acceptable and common for lab environments.

There is **one master node** that runs the Kubernetes control plane components (kube-apiserver, scheduler, and controller manager). The master does **not store data locally**. Instead, it securely connects to the external etcd cluster over HTTPS. For this connection, the API server uses a **separate client certificate** (`apiserver-etcd-client.pem`) that is also signed by the same etcd CA. This separation is required for security and identity verification.

There is **one worker node** that runs application workloads. The worker node never talks to etcd directly. It communicates only with the master node (kube-apiserver), which then reads or writes data to etcd on its behalf.

Overall, the infrastructure clearly separates responsibilities:  
**etcd handles data**, **the master controls the cluster**, and **the worker runs applications**, all secured using TLS with a shared CA and properly scoped certificates.


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