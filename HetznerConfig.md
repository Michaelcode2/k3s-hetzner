# Hetzner Cloud Configuration

To deploy your K3s cluster to a specific Hetzner Cloud project, you need to generate an API Token within that project.

**Important:** Hetzner API tokens are **project-specific**. The token you use determines which project the cluster is deployed to.

## How to Obtain an API Token

1.  Log in to the [Hetzner Cloud Console](https://console.hetzner.cloud/).
2.  Select the **Project** where you want to deploy your cluster.
    *   If you haven't created a project yet, click **+ New Project** and give it a name.
3.  In the left sidebar, click on **Security**.
4.  Switch to the **API Tokens** tab.
5.  Click **Generate API Token**.
6.  Enter a description (e.g., `k3s-cluster-github-actions`).
7.  Select **Read & Write** permissions (this is required to create servers and networks).
8.  Click **Generate API Token**.
9.  **Copy the token immediately**. You will not be able to see it again.

## Using the Token

Add this token as a secret in your GitHub repository:

1.  Go to your GitHub repository.
2.  Navigate to **Settings** > **Secrets and variables** > **Actions**.
3.  Click **New repository secret**.
4.  **Name**: `Hetzner_Token`
5.  **Secret**: Paste your copied API token.
6.  Click **Add secret**.
