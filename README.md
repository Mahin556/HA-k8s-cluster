This setup is about creating a highly available Kubernetes cluster where the cluster keeps working even if one master node goes down.
Because we are not using a cloud load balancer, we use HAProxy on a separate virtual machine to balance traffic between Kubernetes master nodes.

The cluster has:
    3 master nodes (control plane)
    3 worker nodes
    1 load balancer node (HAProxy)
All machines run Linux (Ubuntu)
The main idea is:
    All Kubernetes API traffic goes to the load balancer.
    The load balancer forwards the traffic to any healthy master node.
    If one master fails, traffic automatically goes to the other master.
Below are **all steps with commands**, written in **simple language**, **clear order**, and **no decoration**.
You can follow this directly on servers.

---

### HAProxy

```bash
#Prepare HAProxy LB
#Login to load balancer node.
sudo -i
sudo apt-get update && sudo apt-get upgrade -ye #Update the system
sudo apt install -y haproxy #Install haproxy
sudo nano /etc/haproxy/haproxy.cfg #Edit haproxy configuration
```
Add this at the end of the file
```jsx
{/* This block is essentially the **public-facing listener** for Kubernetes API request */}
frontend kubernetes-frontend
        bind *:6443
        mode tcp
        option tcplog
        default_backend kubernetes-backend


backend kubernetes-backend
        mode tcp
        balance roundrobin
        option tcp-check
        default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
        server master1 <private-ip of master node 01>:6443 check
        server master2 <private-ip of master node 02>:6443 check
        server master3 <private-ip of master node 03>:6443 check
```
##### What this means:

- **`frontend kubernetes-api`**   
    This names the frontend block `kubernetes-api`. It's just an identifier — you could call it anything, but naming it clearly helps for readability.
    
- **`bind *:6443`**
    This tells HAProxy to listen for incoming connections on **port 6443** on **all interfaces** (`*` means all available IPs on the server).
    - Port **6443** is the standard Kubernetes API port.
    - This is the port `kubeadm` and `kubectl` will connect to.

- **`default_backend kube-masters`**
    Any connection received on this frontend will be forwarded to the **`kube-masters` backend** (defined in the next block).

- **`backend kube-masters`**
    This names the backend pool `kube-masters`. This matches the `default_backend` in the frontend section.
    
- **`mode tcp`**
    HAProxy operates in **TCP mode** (not HTTP). The Kubernetes API server uses raw TCP (HTTPS), so this mode is required.
    
- **`balance roundrobin`**
    Load balances incoming connections using **round-robin strategy**:    
    - First request → master1
    - Second request → master2
    - Third → master3
    - Then it repeats...
    This spreads the load evenly across your control plane nodes.
    
- **`option tcp-check`**
    Enables **health checks** using TCP connection attempts. If HAProxy cannot make a TCP connection to a node’s port 6443, it considers that node **unhealthy** and removes it from the rotation.
    
- **`default-server inter 5s fall 3 rise 2`**
    These are health check tuning parameters:
    - `inter 10s`: Check every 10s.
    - `downinter 5s`: If down, recheck every 5s.
    - `rise 2`: Need 2 successful checks to be considered healthy.
    - `fall 2`: 2 failed checks mark the server as down.
    - `slowstart 60s`: After recovery, slowly ramp up traffic over 60s.
    - `maxconn 250`: Max 250 connections.
    - `maxqueue 256`: Queue limit.
    - `weight 100`: Default weight for load balancing.

- **final output**
```jsx
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend kubernetes-api
         bind *:6443
         mode tcp
         option tcplog
         default_backend kube-master-nodes

backend kube-master-nodes
        mode tcp
        balance roundrobin
        option tcp-check
        default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
        server master1 <private-ip of master node 01>:6443 check
        server master2 <private-ip of master node 02>:6443 check
```

```bash
sudo systemctl restart haproxy
sudo systemctl enable haproxy
```
```bash
#Check if the port 6443 is open and responding for haproxy connection or not
ss -lntp | grep 6443
nc -v localhost 6443
```
you will see a response like 
```jsx
Connection to localhost (127.0.0.1) 6443 port [tcp/*] succeeded!`
```
**Note** If you see failures for master1 and master2 connectivity, you can ignore them for time being as we have not yet installed anything on the servers.


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

let see if our load balancer is working fine or not 

```jsx
 sudo journalctl -u haproxy -f
```
you will see a output like this 

```jsx
May 24 21:02:36 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51630 [24/May/2025:21:02:36.367] kubernetes-api kube-master-nodes/master1 1/1/62 2744 -- 10/10/9/5/0 0/0
May 24 21:02:36 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51632 [24/May/2025:21:02:36.367] kubernetes-api kube-master-nodes/master2 1/1/67 2707 -- 9/9/8/3/0 0/0
May 24 21:02:36 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51622 [24/May/2025:21:02:36.367] kubernetes-api kube-master-nodes/master2 1/1/68 2707 -- 8/8/7/2/0 0/0
May 24 21:02:36 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51640 [24/May/2025:21:02:36.382] kubernetes-api kube-master-nodes/master1 1/0/54 2707 -- 7/7/6/4/0 0/0
May 24 21:02:36 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51652 [24/May/2025:21:02:36.382] kubernetes-api kube-master-nodes/master2 1/0/54 2744 -- 6/6/5/1/0 0/0
May 24 21:02:37 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51588 [24/May/2025:21:02:36.354] kubernetes-api kube-master-nodes/master1 1/0/939 21869 -- 6/6/5/4/0 0/0
May 24 21:02:37 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51484 [24/May/2025:21:02:34.968] kubernetes-api kube-master-nodes/master1 1/0/2394 8113 -- 6/6/5/3/0 0/0
May 24 21:02:37 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:36926 [24/May/2025:21:02:37.339] kubernetes-api kube-master-nodes/master2 1/0/24 7446 -- 5/5/4/1/0 0/0
May 24 21:04:06 ip-10-0-0-10 haproxy[19490]: 10.0.0.248:51498 [24/May/2025:21:02:36.291] kubernetes-api kube-master-nodes/master2 1/0/90112 7989 -- 5/5/4/0/0 0/0
May 24 21:04:53 ip-10-0-0-10 haproxy[19490]: 10.0.0.49:36898 [24/May/2025:21:04:53.770] kubernetes-api kube-master-nodes/master2 1/0/19 15526 -- 5/5/4/0/0 0/0

```

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

### ENABLE HAPROXY STATS (OPTIONAL)
```bash
#Edit the HAProxy configuration file:
sudo nano /etc/haproxy/haproxy.cfg

#Add the following configuration at the end of the file:
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /
    stats refresh 10s

#Restart the HAProxy service to apply the changes:
sudo systemctl restart haproxy

#Access the HAProxy stats page in a browser:
http://LOAD_BALANCER_IP:8404
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