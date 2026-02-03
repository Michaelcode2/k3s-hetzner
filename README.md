# K3s & ArgoCD on Hetzner Cloud

This project automates the deployment of a production-ready K3s cluster on Hetzner Cloud and installs ArgoCD for GitOps-based continuous delivery. It uses the `hetzner-k3s` CLI tool wrapped in GitHub Actions workflows.

## Features

- **Automated K3s Provisioning**: Deploys a secure K3s cluster (master + worker) using [hetzner-k3s](https://github.com/vitobotta/hetzner-k3s).
- **ArgoCD Integration**: Automatically installs ArgoCD for application management.
- **Infrastructure as Code**: Cluster configuration and deployment logic are version controlled.
- **GitHub Actions**: Fully automated provisioning and deployment pipelines.

## Project Structure

- `scripts/deploy-k3s.sh`: Script to download `hetzner-k3s` and provision the cluster.
- `config/cluster.yaml.template`: Cluster configuration template.
- `.github/workflows/provision-k3s.yml`: Workflow to provision infrastructure.
- `.github/workflows/deploy-argocd.yml`: Workflow to deploy ArgoCD.
- `Ingress.md`: Comprehensive guide for ingress configuration options.

## Prerequisites

Before running the workflows, you need:

1.  **Hetzner Cloud Account**: Create a project in the Hetzner Cloud Console.
2.  **API Token**: Generate a Read/Write API Token for your project. (See [HetznerConfig.md](HetznerConfig.md) for details).
3.  **SSH Keys**: Generate an SSH key pair for cluster access.

## Important Notes

⚠️ **Traefik Ingress Controller**: The hetzner-k3s tool does NOT install Traefik by default. You must explicitly enable it in your `cluster.yaml` configuration file by adding `enable_traefik: true`. Without Traefik, the ArgoCD ingress will not work.

## Configuration

Add the following secrets to your GitHub Repository:

| Secret Name | Description |
| :--- | :--- |
| `HETZNER_TOKEN` | Your Hetzner Cloud API Token. |
| `SSH_PRIVATE_KEY` | The private SSH key for the cluster. |
| `SSH_PUBLIC_KEY` | The public SSH key for the cluster. |
| `KUBECONFIG` | (Optional) Kubeconfig file content. Required only for standalone ArgoCD deployment workflow. |

## Usage

### 1. Provision the Cluster
Go to the **Actions** tab in GitHub and select the **Provision K3s Cluster** workflow. Trigger it manually using `workflow_dispatch`. This will:
- Create the servers on Hetzner.
- Install K3s.
- Upload the `kubeconfig` file as a workflow artifact.

For instructions on scaling the cluster or upgrading K3s, see [ClusterManagement.md](ClusterManagement.md).

### 2: ArgoCD Deployment

If you want to deploy ArgoCD (e.g., to an existing cluster), you can use the **Deploy ArgoCD ** workflow. For this to work, you need to:

1. Download the `kubeconfig` artifact from a previous provisioning workflow run
2. Add it as a GitHub Secret named `KUBECONFIG` in your repository settings
3. Run the standalone ArgoCD deployment workflow

**Note**: The combined workflow (Option 1) is recommended as it handles everything automatically without requiring manual secret configuration.

### ArgoCD on Control Plane

The deployment workflow automatically patches ArgoCD components to run on the control plane nodes. This is useful for optimizing resource usage in smaller clusters. The workflow injects the necessary `tolerations` and `nodeSelector` to bypass the `CriticalAddonsOnly` taint on master nodes.

To enable Argo deployment on the controlplane node, uncomment Workflow job "Patch ArgoCD for Control Plane"

## Accessing the Cluster

1.  Download the `kubeconfig` artifact from the **Provision K3s Cluster** workflow run.
2.  Set your local `KUBECONFIG` environment variable:
    ```bash
    export KUBECONFIG=/path/to/downloaded/kubeconfig
    ```
3.  Verify connection:
    ```bash
    kubectl get nodes
    ```

## Accessing ArgoCD

After deployment, you'll need to retrieve your admin credentials:

### Get Admin Password

For security reasons, the password is **not displayed in workflow logs**. Retrieve it using:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

**Credentials:**
- **Username**: `admin`
- **Password**: Retrieved using the command above

### Option 1: Via Ingress (Recommended)

The deployment configures an Ingress resource using Traefik. You can access ArgoCD via:

**Using NodePort:**
```
https://<NODE_IP>:30443
```

**Using Hetzner Load Balancer + Domain (Production):**
```
https://argocd.yourdomain.com
```

*Note: You may see a certificate warning with self-signed certificates. See [Ingress.md](Ingress.md) for Let's Encrypt setup.*

📚 **For detailed ingress configuration options, DNS setup, and production recommendations, see [Ingress.md](Ingress.md)**

### Option 2: Port Forwarding

Alternatively, you can port-forward the service locally:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Access at `https://localhost:8080`.

## Troubleshooting

### Re-deploying ArgoCD

If you need to re-deploy ArgoCD (e.g., after making configuration changes), first clean up the existing installation:

```bash
# Delete the entire ArgoCD namespace
kubectl delete namespace argocd

# Wait for namespace to be fully deleted
kubectl wait --for=delete namespace/argocd --timeout=60s

# Then re-run the Deploy ArgoCD workflow
```

### Common Issues

**Issue**: `No resources found` when running `kubectl get ingressclass`  
**Solution**: Traefik is NOT installed by default in hetzner-k3s clusters. You must:
1. Add `enable_traefik: true` to your `cluster.yaml` configuration
2. Re-provision the cluster OR manually install Traefik:
```bash
# Quick fix: Create IngressClass manually (if Traefik pods exist but IngressClass is missing)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: traefik
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: traefik.io/ingress-controller
EOF
```

**Issue**: `metadata.annotations: Too long` error during installation  
**Solution**: The workflow uses `--server-side` apply which handles this automatically. If you're applying manually, use:
```bash
kubectl apply --server-side -n argocd -f <manifest>
```

**Issue**: Ingress returns 502 Bad Gateway  
**Solution**: Ensure ArgoCD server is running in insecure mode behind the ingress. The workflow handles this automatically by configuring the `argocd-cmd-params-cm` ConfigMap.

**Issue**: `no matches for kind "ServersTransport"` error  
**Solution**: This project uses a simplified ingress configuration that doesn't require Traefik CRDs. Make sure you're using the latest `config/argocd-ingress.yaml` from the repository.
