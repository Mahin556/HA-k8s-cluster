```bash
# first add our custom repo to your local helm repositories
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/

# now you should be able to install headlamp via helm
helm install my-headlamp headlamp/headlamp --namespace kube-system
```
```bash
kubectl -n kube-system create serviceaccount headlamp-admin

kubectl create clusterrolebinding headlamp-admin --serviceaccount=kube-system:headlamp-admin --clusterrole=cluster-admin

kubectl create token headlamp-admin -n kube-system
```
```bash
kubectl port-forward -n kube-system service/headlamp 8080:80
```

### reference:
- https://headlamp.dev/docs/latest/installation/#create-a-service-account-token
- https://headlamp.dev/docs/latest/installation/in-cluster/