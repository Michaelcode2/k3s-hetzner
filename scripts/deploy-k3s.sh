#!/bin/bash
set -e

# Configuration
VERSION="v2.4.5"
BINARY="./hetzner-k3s"
CONFIG_TEMPLATE="config/cluster.yaml.template"
FINAL_CONFIG="cluster.yaml"

# Check for required environment variables
if [ -z "$HETZNER_TOKEN" ]; then
    echo "Error: HETZNER_TOKEN is not set."
    exit 1
fi

if [ -z "$SSH_PRIVATE_KEY" ]; then
    echo "Error: SSH_PRIVATE_KEY is not set."
    exit 1
fi

if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "Error: SSH_PUBLIC_KEY is not set."
    exit 1
fi

# Download hetzner-k3s if not present
if [ ! -f "$BINARY" ]; then
    echo "Downloading hetzner-k3s $VERSION..."
    curl -Lo "$BINARY" "https://github.com/vitobotta/hetzner-k3s/releases/download/$VERSION/hetzner-k3s-linux-amd64"
    chmod +x "$BINARY"
fi

# Prepare SSH keys
echo "Setting up SSH keys..."
mkdir -p ~/.ssh
echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
echo "$SSH_PUBLIC_KEY" > ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Set variables for template substitution
export SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
export SSH_PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa.pub"
export CLUSTER_NAME="${CLUSTER_NAME:-k3s-cluster}"
# HETZNER_TOKEN is already set in env

# Generate config file
echo "Generating $FINAL_CONFIG from $CONFIG_TEMPLATE..."
if command -v envsubst &> /dev/null; then
    envsubst < "$CONFIG_TEMPLATE" > "$FINAL_CONFIG"
else
    # Fallback if envsubst is missing (simple sed replacement for key vars)
    echo "envsubst not found, using sed fallback..."
    cp "$CONFIG_TEMPLATE" "$FINAL_CONFIG"
    sed -i "s|\$HETZNER_TOKEN|$HETZNER_TOKEN|g" "$FINAL_CONFIG"
    sed -i "s|\$CLUSTER_NAME|$CLUSTER_NAME|g" "$FINAL_CONFIG"
    sed -i "s|\$SSH_PUBLIC_KEY_PATH|$SSH_PUBLIC_KEY_PATH|g" "$FINAL_CONFIG"
    sed -i "s|\$SSH_PRIVATE_KEY_PATH|$SSH_PRIVATE_KEY_PATH|g" "$FINAL_CONFIG"
fi

# Deploy cluster
echo "Deploying K3s cluster..."
"$BINARY" create --config "$FINAL_CONFIG"

echo "Deployment finished."
