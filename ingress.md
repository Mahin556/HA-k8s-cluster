# 🔥 Why We Use Ingress Controller (Simple Explanation)

Without ingress:

* Every app needs a **separate NodePort**
* Example:

  * App1 → 32059
  * App2 → 32060
  * App3 → 32061
* You must add all those ports in HAProxy ❌
* Hard to manage

With ingress:

* Only **ONE NodePort for HTTP**
* Only **ONE NodePort for HTTPS**
* NGINX handles routing internally
* HAProxy only forwards to **one port**

Much cleaner ✅

---

# 🧠 Traffic Flow (Very Simple)

```
Client
   ↓
Load Balancer (VIP:80 or 443)
   ↓
WorkerIP:32059 (Ingress NodePort)
   ↓
NGINX Ingress
   ↓
Correct Service
   ↓
Pod
```

---

# Step 1️⃣ Deploy NGINX Ingress

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.2.0/deploy/static/provider/baremetal/deploy.yaml
```

---

# Step 2️⃣ Expose Ingress as NodePort

Create `nginx-service.yaml`

```
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 32059
    - name: https
      port: 443
      targetPort: 443
      nodePort: 32423
  selector:
    app.kubernetes.io/name: ingress-nginx
```

Apply it:

```
kubectl apply -f nginx-service.yaml
```

Now:

* HTTP → 32059
* HTTPS → 32423

---

# Step 3️⃣ Configure HAProxy (Simple Version)

```
frontend http
    bind 192.168.29.100:80
    mode tcp
    default_backend ingress-http

backend ingress-http
    mode tcp
    balance roundrobin
    server workerone 192.168.29.71:32059 check
    server workertwo 192.168.29.72:32059 check


frontend https
    bind 192.168.29.100:443
    mode tcp
    default_backend ingress-https

backend ingress-https
    mode tcp
    balance roundrobin
    server workerone 192.168.29.71:32423 check
    server workertwo 192.168.29.72:32423 check
```

That’s it.

HAProxy only forwards to ingress NodePort.

---

# Step 4️⃣ Create Ingress Rule

Example for app:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

Now:

If user accesses:

```
http://myapp.local
```

NGINX sends traffic to `my-service`.

---

# Why This Is Better

Without ingress:
* 10 apps = 10 NodePorts
* 10 HAProxy entries

With ingress:
* Only 2 HAProxy entries (80 & 443)
* NGINX handles routing

Much cleaner. Much scalable.
