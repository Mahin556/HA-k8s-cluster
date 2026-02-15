#### Check from ETCD nodes
```bash
unset ETCDCTL_ENDPOINTS
unset ETCDCTL_CACERT
unset ETCDCTL_CERT
unset ETCDCTL_KEY


export ENDPOINTS=https://etcdone:2379,https://etcdtwo:2379,https://etcdthree:2379
export ETCDCTL_CACERT=/etc/etcd/pki/ca.pem
export ETCDCTL_CERT=/etc/etcd/pki/apiserver-etcd-client.pem
export ETCDCTL_KEY=/etc/etcd/pki/apiserver-etcd-client-key.pem

etcdctl --endpoints=$ENDPOINTS get / --prefix --keys-only


export ENDPOINTS=https://etcdone:2379,https://etcdtwo:2379,https://etcdthree:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/etcd-ca.pem
export ETCDCTL_CERT=/etc/kubernetes/pki/apiserver-etcd-client.pem
export ETCDCTL_KEY=/etc/kubernetes/pki/apiserver-etcd-client-key.pem

etcdctl --endpoints=$ENDPOINTS get / --prefix --keys-only
```
