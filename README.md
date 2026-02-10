## High Availability (HA) – Core Concept

High Availability (HA) means a system is **available and responsive most of the time**, not all the time. Absolute availability is impossible. In practice, HA is measured using **“nines”** such as 99%, 99.9%, or 99.99% uptime—the more nines, the less downtime is tolerated.

To achieve HA, a system must be **fault tolerant**, **scalable**, and free of **single points of failure**. If a component fails and the system cannot recover automatically, or if only one instance of a critical component exists, true HA cannot be achieved.

---

## Kubernetes and HA Basics

Kubernetes consists of three major parts: the **control plane**, the **worker nodes**, and the **applications** running on those nodes. The control plane acts as the brain of the cluster, deciding what should run, where it should run, and continuously reconciling desired and actual state. Worker nodes are responsible only for running workloads.

The principles used to make Kubernetes highly available are the same principles used to design any highly available distributed system.

---

## Control Plane Availability

A **single control-plane node is not highly available**. If it fails, the entire cluster becomes unavailable, regardless of how quickly the node is restored.

Using **two control-plane nodes is also not HA**. Kubernetes relies on quorum-based decision making, where a majority (more than 50%) must agree on every state change. With two nodes, the majority is two. If one node fails, quorum is lost, leading to split-brain risk. Functionally, two control-plane nodes are no better than one.

The **minimum number of control-plane nodes required for HA is three**. With three nodes, the cluster can tolerate the failure of one node while still maintaining quorum. This makes three the smallest viable HA configuration.

Adding four control-plane nodes does not improve availability and only wastes resources. The quorum requirement becomes three out of four, meaning the cluster can still tolerate only one failure—exactly the same as with three nodes. Five control-plane nodes are better than three because they can tolerate two failures, but they introduce higher cost and coordination overhead. Beyond five nodes, the system becomes slower and unnecessarily complex.

**Rule:** Always use an **odd number** of control-plane nodes (3 or 5). Even numbers provide no HA benefit.

---

## External Load Balancer

In an HA setup, clients must never connect directly to individual control-plane nodes. Instead, an **external load balancer** provides a single, stable Kubernetes API endpoint and forwards requests only to healthy control-plane nodes.

Without a load balancer, failures or upgrades of control-plane nodes would immediately break cluster access. However, the load balancer itself can become a **single point of failure**. Cloud providers typically solve this by offering managed, highly available load balancers. In on-prem environments, load balancer HA must be designed explicitly using multiple load balancers, VRRP, or similar techniques.

---

## Data Centers, Regions, and Zones

A cluster running entirely in **one data center cannot be truly HA**. If the data center fails, everything fails. Two data centers are also insufficient, because losing one removes 50% of the control plane and breaks quorum.

The **minimum requirement for true HA is three data centers or zones** that are independent (power, networking, failure domains) yet close enough to avoid high latency. In cloud environments, these are known as **availability zones** within a region. Kubernetes clusters should be deployed as **regional clusters**, not zonal clusters, to achieve HA.

---

## Worker Nodes and Cost Considerations

Worker nodes do not participate in quorum; they only run workloads. High availability for applications comes from **replication across nodes and zones**.

If resources are limited, it is better to run **three nodes that act as both control plane and workers** than to run a single control-plane node with separate workers. This is a compromise and not recommended for production, but it is still better than having a non-HA control plane.

In ideal production setups, control-plane nodes and worker nodes are separate and distributed across zones. A minimum of **three worker nodes**, one per zone, is recommended.

---

## Storage and Infrastructure HA

HA is not limited to compute resources. Storage, networking, and all supporting infrastructure must also be **replicated**, **distributed**, and **available across zones**. If storage is not highly available, the cluster is not highly available, even if the control plane is.

---

## Highly Available Applications

Running applications on an HA cluster does not automatically make them HA. Applications themselves must be designed for availability. If an application cannot run more than one replica, it can never be highly available.

Stateless applications are easy to scale and make HA. Stateful applications are difficult because data consistency, replication, and shared storage introduce complexity. Best practice is to keep applications stateless, store state in **external databases**, and ensure that those databases are themselves highly available and replicated.

---

## Quorum and etcd in Kubernetes

In Kubernetes, **master nodes do not form a quorum**. Quorum is handled entirely by **etcd**, which is the system of record for all cluster state. Control-plane components—kube-apiserver, kube-scheduler, and kube-controller-manager—are stateless. They do not vote or coordinate decisions among themselves. Every meaningful decision is written to etcd, and etcd uses quorum to decide whether a change is committed.

etcd requires quorum for **every operation that changes cluster state**, including creating, updating, or deleting Pods, Deployments, Services, ConfigMaps, Secrets, node status updates, leader election data, leases, namespaces, RBAC objects, and any `kubectl apply`, `create`, `delete`, or `patch` operation. If etcd loses quorum, all write operations fail.

Read operations such as `kubectl get` or `kubectl describe` do not require quorum. This is why a cluster can appear partially functional when quorum is lost: the API server may still respond to read requests, but all state-changing operations fail, making the cluster effectively **read-only**.

etcd enforces quorum using the **Raft consensus algorithm** to guarantee strong consistency, prevent split-brain scenarios, and ensure correct ordering of state changes. Without quorum, etcd refuses writes rather than risk data corruption.

This is why **two masters or two etcd nodes do not provide HA**. With two members, quorum requires both to be available. Losing one node results in quorum loss, making the system behave like a single-node cluster. For this reason, Kubernetes and etcd always recommend **odd numbers**, with three being the minimum for a highly available control plane.

---

### References

* [https://github.com/jaiswaladi246/HA-K8-Cluster/tree/main](https://github.com/jaiswaladi246/HA-K8-Cluster/tree/main)
* [https://github.com/piyushsachdeva/CKA-2024/blob/main/Resources/Day55-HA-Controlplane.md](https://github.com/piyushsachdeva/CKA-2024/blob/main/Resources/Day55-HA-Controlplane.md)
* [Day 55 – Kubernetes Multi Master Cluster Setup With Load Balancer](https://www.youtube.com/watch?v=dGUAanaYr8o)
* [HA Kubernetes Cluster Setup | Highly Available K8 Cluster](https://youtu.be/JXbTyz1QIHI?si=rSyC4p-J52pcoKdj)
* [https://kubernetes.io/docs/concepts/cluster-administration/addons/](https://kubernetes.io/docs/concepts/cluster-administration/addons/)
* [https://www.tigera.io/project-calico/](https://www.tigera.io/project-calico/)

