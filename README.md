```bash
# On server1
vagrant up master-1

# On server2
vagrant up etcd-1 etcd-2 etcd-3
vagrant up worker-1
```

### Vagrant Environment

|Role|FQDN|IP|OS|RAM|CPU|
|----|----|----|----|----|----|
|Etcd 1|etcdone.example.com|192.168.29.61|Ubuntu 22.04|1G|1|
|Etcd 2|etcdtwo.example.com|192.168.29.62|Ubuntu 22.04|1G|1|
|Etcd 3|etcdthree.example.com|192.168.29.63|Ubuntu 22.04|1G|1|
|Master|masterone.example.com|192.168.29.51|Ubuntu 22.04|2G|2|
|Worker|workerone.example.com|192.168.29.71|Ubuntu 22.04|1G|1|



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