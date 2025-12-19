This setup is about creating a highly available Kubernetes cluster where the cluster keeps working even if one master node goes down.
Because we are not using a cloud load balancer, we use HAProxy on a separate virtual machine to balance traffic between Kubernetes master nodes.

The cluster has:
    3 master nodes (control plane)
    3 worker nodes
    1 NLB
All machines run Linux (Ubuntu)
The main idea is:
    All Kubernetes API traffic goes to the load balancer.
    The load balancer forwards the traffic to any healthy master node.
    If one master fails, traffic automatically goes to the other master.
Below are **all steps with commands**, written in **simple language**, **clear order**, and **no decoration**.
You can follow this directly on servers.

---

### All Cluster Nodes
```bash
#SSH into the Master EC2 server
sudo -i

#Disable Swap using the below commands
swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Verify that the br_netfilter, overlay modules are loaded by running the following commands:
lsmod | grep br_netfilter
lsmod | grep overlay

# Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, and net.ipv4.ip_forward system variables are set to 1 in your sysctl config by running the following command:
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

#Install container runtime
curl -LO https://github.com/containerd/containerd/releases/download/v1.7.14/containerd-1.7.14-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-1.7.14-linux-amd64.tar.gz
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mkdir -p /usr/local/lib/systemd/system/
sudo mv containerd.service /usr/local/lib/systemd/system/
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Check that containerd service is up and running
systemctl status containerd

#Install runc
curl -LO https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

#Install kubeadm,kublet and kubectl
# Step 1: Update system and install required packages
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Step 2: Add Kubernetes apt repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Step 3: Update package list
sudo apt-get update

# Step 4: Install specific Kubernetes versions (adjust version if needed)
sudo apt-get install -y kubelet=1.33.0-1.1 kubeadm=1.33.0-1.1 kubectl=1.33.0-1.1 --allow-downgrades --allow-change-held-packages

# Step 5: Hold the package versions to prevent upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# Step 6: Verify installation
kubeadm version
kubelet --version
kubectl version --client

#check kubelet in properly installed and enabled or not
systemctl status kubelet
```

#### Master Leader Node Leader
```bash
#Initialize  kubeadm
kubeadm init \
  --control-plane-endpoint "<load-balancer-private-ip>:6443" \
  --upload-certs \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<private-ip-of-this-ec2-instance>
#It will generate a control plane token and worker token 
```
```bash
PROBLEM EXPLANATION AND FINAL SOLUTION (KUBERNETES HA + HAPROXY)

What was the problem

When Kubernetes is initialized, it creates a TLS certificate for the API server.
This certificate contains a list of allowed IP addresses and DNS names called
Subject Alternative Names (SANs).

In this setup:
- kubectl, worker nodes, and other control plane nodes access the API server
  through HAProxy
- They connect using the HAProxy public IP
- But the API server certificate did NOT include the HAProxy public IP

Because of this:
- TLS verification failed
- kubectl and kubeadm could not securely connect to the API server
- Certificate or connection errors appeared

Why this happened

By default, kubeadm only includes:
- control plane node IPs
- localhost
- the Kubernetes service IP

It does NOT automatically include:
- the load balancer (HAProxy) public IP

So when traffic reached the API server via the HAProxy public IP, Kubernetes
rejected the connection due to a SAN mismatch.

How the fix works

We explicitly tell kubeadm:
“Trust connections coming from the HAProxy public IP as well.”

This is done by adding the following flag during initialization:

--apiserver-cert-extra-sans=<public-ip-of-haproxy>

When this flag is used:
- The API server certificate is regenerated
- The HAProxy public IP is added to the SAN list
- TLS verification succeeds
- API access through the load balancer works correctly

Important rule

This fix MUST be applied during `kubeadm init`.
It cannot be safely fixed later without regenerating certificates.

Final and correct kubeadm init command

kubeadm init \
  --control-plane-endpoint "<LOAD_BALANCER_PRIVATE_IP>:6443" \
  --apiserver-advertise-address <PRIVATE_IP_OF_THIS_CONTROL_PLANE_NODE> \
  --apiserver-cert-extra-sans=<HAPROXY_PUBLIC_IP> \
  --upload-certs \
  --pod-network-cidr=192.168.0.0/16

Replace the placeholders

<LOAD_BALANCER_PRIVATE_IP>
- Private IP of the HAProxy / load balancer

<PRIVATE_IP_OF_THIS_CONTROL_PLANE_NODE>
- Private IP of the current control plane node

<HAPROXY_PUBLIC_IP>
- Public IP of the HAProxy server

What this command ensures

- High availability using a load balancer
- All nodes communicate through the load balancer endpoint
- HAProxy public IP is trusted by the API server
- No TLS or certificate errors
- Additional control plane nodes can join securely
```
```bash
#Configure kubeconfig for a regular (non-root) user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#or
export KUBECONFIG=/etc/kubernetes/admin.conf
```
```bash
#Check control plane node status:
kubectl get nodes
```
```bash
#Join token for other control-plane nodes
kubeadm join <load-balancer-private-ip>:6443 --token <token> \
--discovery-token-ca-cert-hash sha256:<hash> \
--control-plane --certificate-key <certificate-key>

#Join token for worker nodes
kubeadm join <load-balancer-private-ip>:6443 --token <token> \
--discovery-token-ca-cert-hash sha256:<hash>
```
```bash
#INSTALL POD NETWORK (CALICO)(network addon) to start pod to pod communication
#kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O

kubectl apply -f custom-resources.yaml
#After this if you do `kubectl get nodes` you will see your control-plnae node is ready state.
```
```bash
#INSTALL INGRESS CONTROLLER (OPTIONAL)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.49.0/deploy/static/provider/baremetal/deploy.yaml
kubectl get pods -n ingress-nginx
```

### Other Master Nodes

Now use the join command to join the control plane leader node
```bash
#Join token for other control-plane nodes
kubeadm join <load-balancer-private-ip>:6443 --token <token> \
--discovery-token-ca-cert-hash sha256:<hash> \
--control-plane --certificate-key <certificate-key>
```
![image](https://github.com/user-attachments/assets/55a35340-9935-4727-8a1d-6297ba9f05cc)

you will see a message like this if everything goes right

This node has joined the cluster and a new control plane instance was created:

- Certificate signing request was sent to apiserver and approval was received.
- The Kubelet was informed of the new secure connection details.
- Control plane label and taint were applied to the new node.
- The Kubernetes control plane instances scaled up.
- A new etcd member was added to the local/stacked etcd cluster.

To start administering your cluster from this node, you need to run the following as a regular user:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

```

Run `'kubectl get nodes`' to see this node join the cluster.

---

### Worker node steps
Use the previously generated commands to join the worker nodes to the control plane 

The command looks like this:
```bash
#Join token for worker nodes
kubeadm join <load-balancer-private-ip>:6443 --token <token> \
--discovery-token-ca-cert-hash sha256:<hash>
```

![image](https://github.com/user-attachments/assets/8386eaa5-aea6-45b2-a104-baf4502faa62)

  if everything goes right you will a message like this

This node has joined the cluster:

- Certificate signing request was sent to apiserver and a response was received.
- The Kubelet was informed of the new secure connection details.

Run '`kubectl get nodes`' on the control-plane to see this node join the cluster.

![image](https://github.com/user-attachments/assets/4cac178f-6216-4a93-b78e-27419883210c)


---
 
### Testing
Now your multi control node cluster with stacked etcd is ready you can try provision a pod now:
```jsx
kubectl run nginx --image=nginx --port=80
```

**Configure Your Local kubeconfig**
You need a valid `kubeconfig` file that points to the HAProxy public IP.
On your **local PC**:

Step 1: Copy the `admin.conf` from any control plane node:
From the control plane node:
```jsx
cat /etc/kubernetes/admin.conf
```

Copy the contents, or use `scp`:
```bash
scp -i your-key.pem ec2-user@<control-plane-ip>:/etc/kubernetes/admin.conf ~/haproxy-kubeconfig.yaml
```

Step 2: Edit the config:
In the copied config file (`haproxy-kubeconfig.yaml`):

- Replace:  
    ```yaml
    server: https://<control-plane-private-ip>:6443
    ```
    with:
    ```yaml
    server: https://<your-haproxy-public-ip>:6443
    ```
    
- Save the file.

**Test the Connection**
On your **local PC**, run:
```bash
KUBECONFIG=~/haproxy-kubeconfig.yaml kubectl get nodes

$ KUBECONFIG=./config kubectl get pods
NAME     READY   STATUS    RESTARTS   AGE
nginx    1/1     Running   0          5m46s
nginx1   1/1     Running   0          5m21s
nginx2   1/1     Running   0          5m12s
```

Go to the load balanced ---> health check ---> healty and unhealthy nodes

---

### Generate join command
```bash
# On Lead Master Node
kubeadm token create --print-join-command --certificate-key \
$(kubeadm init phase upload-certs --upload-certs | tail -1) #For other master nodes

kubeadm token create --print-join-command #For worker nodes
```
```bash
#Join Nodes to cluster

#Join other master nodes to cluster
sudo kubeadm join LOAD_BALANCER_IP:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>

#Join worker nodes to cluster
sudo kubeadm join LOAD_BALANCER_IP:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```
```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```


---

### VERIFY ETCD HEALTH
```bash
#Install etcdctl on a master node:
sudo apt install -y etcd-client

#Check etcd cluster health:
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  endpoint health

#Check etcd cluster members:
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  member list
```

---

### TEST HIGH AVAILABILITY
```bash
# Stop kubelet on one control plane node to simulate failure:
sudo systemctl stop kubelet

# From another control plane node or any node with kubectl access,
# verify the cluster status:
kubectl get nodes

# Test Kubernetes API access through the load balancer:
curl -k https://LOAD_BALANCER_IP:6443/version

$ curl -k https://13.201.4.135:6443/version
{
  "major": "1",
  "minor": "33",
  "emulationMajor": "1",
  "emulationMinor": "33",
  "minCompatibilityMajor": "1",
  "minCompatibilityMinor": "32",
  "gitVersion": "v1.33.7",
  "gitCommit": "a7245cdf3f69e11356c7e8f92b3e78ca4ee4e757",
  "gitTreeState": "clean",
  "buildDate": "2025-12-09T14:35:23Z",
  "goVersion": "go1.24.11",
  "compiler": "gc",
  "platform": "linux/amd64"
}

# The API should respond successfully, confirming that
# HAProxy has redirected traffic to a healthy control plane node
# and the cluster is still operational.

# FINAL RESULT
# - Kubernetes API is always accessed through the load balancer
# - Multiple control plane nodes share responsibility
# - etcd maintains a consistent and highly available cluster state
# - Worker nodes continue running workloads independently
# - The cluster remains available even if one control plane node fails
```
```bash
# If the number of control plane (master) nodes drops below the required quorum, etcd cannot form a majority and stops serving read/write requests.

# As a result, the Kubernetes API server cannot access cluster state, and kubectl commands fail with an error like:

root@ip-10-0-1-200:~# KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes
Error from server: etcdserver: request timed out

# This is expected behavior and exists to protect data consistency.
# It indicates quorum loss, not a configuration issue.
```