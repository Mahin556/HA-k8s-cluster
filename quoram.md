```bash
WHY THE CLUSTER WORKS WITH 2 MASTERS BUT FAILS WITH ONLY 1 MASTER (QUORUM EXPLAINED)

What is happening in this HA Kubernetes setup

You created a Kubernetes cluster with:
- 3 control plane (master) nodes
- 2 worker nodes
- A load balancer in front of the masters
- Stacked etcd (each master runs an etcd member)

All kubectl requests go:
kubectl → Load Balancer → API Server → etcd

The API server itself does not store data.
etcd is the single source of truth for the entire cluster state.

Why the cluster works with 3 masters

With 3 master nodes, you have:
- 3 etcd members

etcd uses quorum to decide if it can serve read/write requests.

Quorum formula:
(total etcd members / 2) + 1

For 3 etcd members:
3 / 2 = 1.5
1.5 + 1 = 2.5 → rounded down to 2

So:
At least 2 etcd members must be UP.

When all 3 masters are running:
- Quorum is satisfied
- etcd serves requests
- kubectl works
- Cluster is healthy

Why the cluster still works when 1 master goes down

When 1 master is stopped:
- 2 masters remain
- 2 etcd members are still running

Quorum requirement = 2
Available etcd members = 2

Quorum is satisfied.

Result:
- API server continues to work
- Load balancer sends traffic to healthy masters
- kubectl commands work normally
- Cluster is still highly available

Why the cluster fails when only 1 master is left

When 2 masters are stopped:
- Only 1 master is running
- Only 1 etcd member is alive

Quorum requirement = 2
Available etcd members = 1

Quorum is NOT satisfied.

What happens internally:
- kubectl request reaches the API server
- API server authenticates and authorizes the request
- API server forwards the request to etcd
- etcd refuses the request due to lack of quorum

This results in errors like:
- etcd server request timeout
- kubectl not responding
- cluster appears unavailable

Important point:
This is NOT a misconfiguration.
This is expected and correct behavior.

Why a single-master cluster works but a 3-master cluster with 1 master does not

Single-master cluster:
- 1 master
- 1 etcd member
- Quorum = 1
- etcd works

Three-master cluster:
- 3 etcd members
- Quorum = 2
- With only 1 alive → etcd stops serving requests

etcd prioritizes consistency over availability.

Quorum examples for better understanding

1 master → quorum = 1
3 masters → quorum = 2
5 masters → quorum = 3
7 masters → quorum = 4

Rule:
More masters = higher fault tolerance, but quorum must always be met.

Final conclusion

- The cluster is highly available, not infinitely available
- etcd quorum is mandatory for reads and writes
- With stacked etcd, master count = etcd count
- Losing quorum makes the cluster read/write unavailable
- This behavior protects data consistency

This is exactly how a correctly designed HA Kubernetes cluster is supposed to behave.
```