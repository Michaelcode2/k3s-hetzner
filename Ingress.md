# Ingress Configuration Guide

This guide explains different approaches to expose ArgoCD (and other services) from your K3s cluster on Hetzner Cloud.

## Table of Contents

- [Overview](#overview)
- [Option 1: With Traefik (Recommended)](#option-1-with-traefik-recommended)
- [Option 2: Without Traefik (Direct Exposure)](#option-2-without-traefik-direct-exposure)
- [Option 3: Hetzner Load Balancer + DNS](#option-3-hetzner-load-balancer--dns)
- [Comparison Matrix](#comparison-matrix)
- [Production Recommendations](#production-recommendations)

---

## Overview

When exposing services from Kubernetes, you have several architectural choices:

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌──────────────┴────────────────┐
          │                               │
     NodePort                  Hetzner Load Balancer
     (IP:30443)                  (Dedicated IP:443)
          │                             │
          │                             │
     ┌────┴────┐                   ┌────┴────┐
     │         │                   │         │
  Traefik   Direct               Traefik   Direct
    │       ArgoCD                 │       ArgoCD
    │                              │
  ArgoCD                         ArgoCD
```

---

## Option 1: With Traefik (Recommended)

**Best for:** Production environments, multiple services, domain-based routing

### Architecture

```
Internet → NodePort/LoadBalancer → Traefik → ArgoCD
                                      ├────→ Other Services
                                      └────→ Future Apps
```

### Cluster Configuration

**1. Enable Traefik in `cluster.yaml`:**

```yaml
hetzner_token: $HETZNER_TOKEN
cluster_name: $CLUSTER_NAME
k3s_version: v1.30.2+k3s1

# Enable Traefik
enable_traefik: true

masters_pool:
  instance_type: cpx22
  instance_count: 1
  location: nbg1

worker_node_pools:
- name: workers
  instance_type: cpx32
  instance_count: 1
  location: nbg1
```

**2. Configure ArgoCD Ingress:**

Create `config/argocd-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    # Enable both HTTP and HTTPS entry points
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    # Redirect HTTP to HTTPS
    traefik.ingress.kubernetes.io/redirect-entry-point: websecure
    traefik.ingress.kubernetes.io/redirect-permanent: "true"
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

**3. Apply the Ingress:**

```bash
kubectl apply -f config/argocd-ingress.yaml
```

**4. Access ArgoCD:**

```bash
# Get node IPs
kubectl get nodes -o wide

# Get Traefik NodePort
kubectl get svc -n kube-system traefik

# Access via any node IP
https://<NODE_IP>:30443
```

### With Domain Name

**Update ingress with host-based routing:**

```yaml
spec:
  ingressClassName: traefik
  rules:
  - host: argocd.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

**Configure DNS:**
```
Type: A
Name: argocd
Value: <NODE_IP>
TTL: 300
```

**Access:** `https://argocd.yourdomain.com:30443`

### Pros & Cons

**Advantages:**
✅ Single entry point for multiple services  
✅ Path-based routing: `/argocd`, `/grafana`, `/prometheus`  
✅ Host-based routing: different domains → different services  
✅ Integration with cert-manager for Let's Encrypt  
✅ Standard Kubernetes pattern  
✅ Easy to add more services later  

**Disadvantages:**
❌ Additional component to manage  
❌ Slightly more complex setup  
❌ Still requires port number (30443) unless using Load Balancer  

---

## Option 2: Without Traefik (Direct Exposure)

**Best for:** Single service deployments, simple setups, cost-sensitive environments

### Architecture

```
Internet → NodePort → ArgoCD (direct)
```

### Configuration

**1. Disable Traefik in `cluster.yaml`:**

```yaml
enable_traefik: false
```

**2. Create NodePort Service for ArgoCD:**

Create `config/argocd-nodeport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
spec:
  type: NodePort
  ports:
  - name: https
    port: 443
    targetPort: 8080  # ArgoCD HTTPS port
    nodePort: 30443   # External port
    protocol: TCP
  selector:
    app.kubernetes.io/name: argocd-server
```

**3. Apply:**

```bash
kubectl apply -f config/argocd-nodeport.yaml
```

**4. Access:**

```bash
# Get node IP
kubectl get nodes -o wide

# Access directly
https://<NODE_IP>:30443
```

### Pros & Cons

**Advantages:**
✅ Simpler setup (fewer components)  
✅ Direct connection to ArgoCD  
✅ Lower resource usage  
✅ Easier troubleshooting  

**Disadvantages:**
❌ Each service needs its own NodePort  
❌ No centralized routing  
❌ No path-based or host-based routing  
❌ Harder to scale to multiple services  
❌ No Let's Encrypt integration  

---

## Option 3: Hetzner Load Balancer + DNS

**Best for:** Production environments with custom domains, no port numbers in URL

### Architecture

```
Internet (port 443) → Hetzner LB → Traefik → ArgoCD
                         ↓
                    Stable Public IP
                         ↓
                    DNS: argocd.domain.com
```

### Cost

- **Hetzner Load Balancer:** ~€5.50/month
- **Benefits:** Dedicated public IP, no NodePort, standard ports (80/443)

### Setup

#### Step 1: Enable Traefik with LoadBalancer Type

**Option A: Via Cluster Configuration (Recommended)**

Check hetzner-k3s documentation for load balancer configuration options.

**Option B: Manually Create LoadBalancer Service**

Create `config/traefik-loadbalancer.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik-lb
  namespace: kube-system
  annotations:
    load-balancer.hetzner.cloud/location: nbg1
    load-balancer.hetzner.cloud/name: "k3s-traefik-lb"
    load-balancer.hetzner.cloud/use-private-ip: "false"
    load-balancer.hetzner.cloud/ipv4: "true"
    load-balancer.hetzner.cloud/ipv6: "false"
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: traefik
  ports:
  - name: web
    port: 80
    targetPort: 8000
    protocol: TCP
  - name: websecure
    port: 443
    targetPort: 8443
    protocol: TCP
```

Apply:

```bash
kubectl apply -f config/traefik-loadbalancer.yaml
```

#### Step 2: Get Load Balancer IP

```bash
# Wait for external IP to be assigned (takes ~1-2 minutes)
kubectl get svc traefik-lb -n kube-system -w

# Get the IP
export LB_IP=$(kubectl get svc traefik-lb -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Load Balancer IP: $LB_IP"
```

#### Step 3: Configure DNS

**Option A: Using a DNS Provider (Namecheap, Cloudflare, etc.)**

Add an A record:

```
Type: A
Host: argocd (or @)
Value: <LOAD_BALANCER_IP>
TTL: 300
```

**Option B: Hetzner Cloud DNS (Free)**

```bash
# Install hcloud CLI
brew install hcloud  # macOS
# or
wget https://github.com/hetznercloud/cli/releases/download/v1.42.0/hcloud-linux-amd64.tar.gz

# Login
hcloud context create my-project

# Create DNS zone
hcloud zone create --name yourdomain.com

# Add A record
hcloud zone add-record --zone yourdomain.com --type A --name argocd --value $LB_IP
```

**Option C: Wildcard DNS for Testing (nip.io)**

No DNS registration needed - use nip.io for testing:

```
Access via: argocd.<LB_IP>.nip.io
Example: argocd.95.217.123.45.nip.io
```

#### Step 4: Update ArgoCD Ingress

Update `config/argocd-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/redirect-entry-point: websecure
    traefik.ingress.kubernetes.io/redirect-permanent: "true"
spec:
  ingressClassName: traefik
  rules:
  - host: argocd.yourdomain.com  # Your domain here
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

Apply:

```bash
kubectl apply -f config/argocd-ingress.yaml
```

#### Step 5: Access ArgoCD

```bash
# Via domain (clean URL, no port!)
https://argocd.yourdomain.com

# Via nip.io (for testing)
https://argocd.<LB_IP>.nip.io
```

### Adding Let's Encrypt (Production TLS)

**1. Install cert-manager:**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

**2. Create ClusterIssuer:**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

**3. Update Ingress with TLS:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - argocd.yourdomain.com
    secretName: argocd-tls
  rules:
  - host: argocd.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

**No more certificate warnings!**

### Pros & Cons

**Advantages:**
✅ Clean URLs without port numbers  
✅ Standard HTTPS ports (443)  
✅ Stable public IP (survives node changes)  
✅ Production-ready setup  
✅ Easy Let's Encrypt integration  
✅ Professional appearance  
✅ Supports multiple services with different domains  

**Disadvantages:**
❌ Additional cost (~€5.50/month)  
❌ More complex setup  
❌ Requires DNS management  

---

## Comparison Matrix

| Feature | Direct (No Traefik) | Traefik + NodePort | Traefik + LB + DNS |
|---------|---------------------|--------------------|--------------------|
| **Cost** | €0 | €0 | ~€5.50/month |
| **Setup Complexity** | Simple | Moderate | Complex |
| **URL Format** | `https://IP:30443` | `https://IP:30443` | `https://domain.com` |
| **Multiple Services** | Hard | Easy | Easy |
| **Domain Names** | Manual | Manual | Native |
| **Let's Encrypt** | Manual | Possible | Easy |
| **Production Ready** | ⚠️ Basic | ✅ Yes | ✅ Best |
| **Port Numbers** | ❌ Visible | ❌ Visible | ✅ Hidden |
| **Scalability** | ❌ Limited | ✅ Good | ✅ Excellent |

---

## Production Recommendations

### For Development/Testing
**Use:** Traefik + NodePort
- No extra cost
- Easy to set up
- Access via IP:port is acceptable

### For Small Production
**Use:** Traefik + NodePort + Domain
- Register a domain (~$10/year)
- Point DNS to node IP
- Access via `https://argocd.domain.com:30443`
- Cost-effective compromise

### For Professional Production
**Use:** Traefik + Hetzner LB + DNS + Let's Encrypt
- Professional URLs
- Real TLS certificates
- No certificate warnings
- Stable infrastructure
- Worth the ~€5.50/month

---

## Common Issues & Solutions

### Issue: 404 Not Found

**Cause:** Ingress not routing correctly

**Solution:**
```bash
# Check ingress status
kubectl describe ingress argocd-server-ingress -n argocd

# Verify backend
kubectl get endpoints argocd-server -n argocd

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
```

### Issue: Certificate Warning

**Cause:** Using self-signed certificates

**Solutions:**
1. **Accept the warning** (for testing)
2. **Use Let's Encrypt** (for production)
3. **Import custom CA** (for internal use)

### Issue: Connection Timeout

**Cause:** Firewall blocking ports

**Solution:**
```bash
# Check if ports are accessible
curl -v https://<NODE_IP>:30443

# Verify firewall rules in Hetzner Console
# Ensure ports 30080, 30443 are allowed
```

### Issue: Load Balancer Pending

**Cause:** Hetzner Cloud Controller Manager not configured

**Solution:**
```bash
# Check if CCM is running
kubectl get pods -n kube-system | grep hcloud

# Check service events
kubectl describe svc traefik-lb -n kube-system
```

---

## Next Steps

1. **Choose your architecture** based on requirements and budget
2. **Update cluster configuration** if needed
3. **Configure DNS** for production use
4. **Set up Let's Encrypt** for real TLS certificates
5. **Add monitoring** (Prometheus/Grafana) using the same ingress pattern

For more information:
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Hetzner Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager)
- [cert-manager Documentation](https://cert-manager.io/docs/)
