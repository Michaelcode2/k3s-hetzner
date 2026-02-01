# Cluster Management Guide

This guide covers common Day 2 operations for your Hetzner K3s cluster, including scaling nodes and upgrading the Kubernetes version.

## Scaling the Cluster

### Adding Nodes (Scaling Up)

You can easily add more master or worker nodes by updating the configuration.

1.  **Edit** `config/cluster.yaml.template`.
2.  **Increase** the `instance_count` for the desired pool.

    ```yaml
    worker_node_pools:
    - name: workers
      instance_type: cx22
      instance_count: 3  # Changed from 1 to 3
      location: nbg1
    ```

3.  **Commit and Push** the changes to GitHub.
4.  **Run** the `Provision K3s Cluster` workflow manually.
    *   The `hetzner-k3s` tool is idempotent. It will detect the new nodes are missing, provision them, and join them to the existing cluster. Existing nodes remain untouched.

### Removing Nodes (Scaling Down)

Scaling down requires manual steps to ensure data safety. The tool will **not** automatically delete servers to prevent data loss.

1.  **Identify** the node to remove:
    ```bash
    kubectl get nodes
    ```
2.  **Drain** the node to move workloads elsewhere:
    ```bash
    kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
    ```
3.  **Delete** the node from the cluster:
    ```bash
    kubectl delete node <node-name>
    ```
4.  **Delete** the server from the [Hetzner Cloud Console](https://console.hetzner.cloud/).
5.  **Update** `config/cluster.yaml.template` to match the new count (so future runs don't re-create it).
6.  **Commit** the config change.

## Upgrading K3s Version

Upgrading the Kubernetes version involves a rolling update process.

1.  **Check Available Versions**:
    You can check the [K3s releases](https://github.com/k3s-io/k3s/releases) for the version you want (e.g., `v1.31.1+k3s1`).

2.  **Edit** `config/cluster.yaml.template`:
    Update the `k3s_version` field.

    ```yaml
    k3s_version: v1.31.1+k3s1
    ```

3.  **Run the Upgrade Command**:
    *Note: The standard "Provision" workflow uses `create`, which may not trigger an upgrade on existing nodes.*

    To upgrade, you should run the upgrade command locally or create a specific upgrade workflow.

    **Local Upgrade:**
    ```bash
    # Ensure you have the config generated or env vars set
    export HETZNER_TOKEN="your-token"
    # ... set other env vars ...
    ./hetzner-k3s upgrade --config cluster.yaml --new-k3s-version v1.31.1+k3s1
    ```

    **Via Workflow (Recommended Approach):**
    Currently, the `scripts/deploy-k3s.sh` script only runs `create`. To support upgrades via GitHub Actions, you would need to modify the script or create a new workflow that runs `hetzner-k3s upgrade`.

## Advanced Configuration

### Adding a New Node Pool

You can add entirely new pools for different purposes (e.g., high-memory nodes).

```yaml
worker_node_pools:
- name: workers-standard
  instance_type: cx22
  instance_count: 2
- name: workers-highmem
  instance_type: cx32
  instance_count: 1
```

Running the provision workflow will create the new pool and join the nodes.
