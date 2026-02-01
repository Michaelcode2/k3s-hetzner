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

## Prerequisites

Before running the workflows, you need:

1.  **Hetzner Cloud Account**: Create a project in the Hetzner Cloud Console.
2.  **API Token**: Generate a Read/Write API Token for your project. (See [HetznerConfig.md](HetznerConfig.md) for details).
3.  **SSH Keys**: Generate an SSH key pair for cluster access.

## Configuration

Add the following secrets to your GitHub Repository:

| Secret Name | Description |
| :--- | :--- |
| `HETZNER_TOKEN` | Your Hetzner Cloud API Token. |
| `SSH_PRIVATE_KEY` | The private SSH key for the cluster. |
| `SSH_PUBLIC_KEY` | The public SSH key for the cluster. |

## Usage

### 1. Provision the Cluster
Go to the **Actions** tab in GitHub and select the **Provision K3s Cluster** workflow. Trigger it manually using `workflow_dispatch`. This will:
- Create the servers on Hetzner.
- Install K3s.
- Upload the `kubeconfig` file as a workflow artifact.

For instructions on scaling the cluster or upgrading K3s, see [ClusterManagement.md](ClusterManagement.md).

### 2. Deploy ArgoCD
Once the cluster is ready, run the **Deploy ArgoCD** workflow.

*Note: For the automated pipeline to fully work between jobs, you may need to configure the `KUBECONFIG` secret in your repository using the output from the provisioning step.*

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

After deployment, retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Option 1: Via Ingress (Recommended)

The deployment configures an Ingress resource using Traefik. You can access ArgoCD via the public IP of your master node:

```
https://<MASTER_NODE_IP>/
```

*Note: You may see a certificate warning because of the default self-signed certificate.*

### Option 2: Port Forwarding

Alternatively, you can port-forward the service locally:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Access at `https://localhost:8080`.
