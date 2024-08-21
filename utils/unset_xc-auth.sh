#!/bin/bash

# Prompt the user for the desired username (Common Name for the certificate)
read -p "Enter the desired username for the client certificate: " USERNAME

# Prompt the user for the desired kubeconfig file path (default: ~/.kube/config)
read -p "Enter the kubeconfig file path to remove [default: ~/.kube/config]: " KUBECONFIG_PATH
KUBECONFIG_PATH=${KUBECONFIG_PATH:-~/.kube/config}

# Define destination directory
DEST_DIR=~/certs

# Install jq if not already installed
if ! command -v jq &> /dev/null; then
  echo "jq is not installed. Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
  if [ $? -ne 0 ]; then
    echo "Failed to install jq. Exiting."
    exit 1
  fi
else
  echo "jq is already installed."
fi

# Check if the kubeconfig file exists
if [ -f "$KUBECONFIG_PATH" ]; then
  echo "Removing context, user, and cluster from kubeconfig file at $KUBECONFIG_PATH..."

  # Remove context, user, and cluster from kubeconfig
  kubectl config --kubeconfig=$KUBECONFIG_PATH unset contexts.$USERNAME@kubernetes-cluster
  kubectl config --kubeconfig=$KUBECONFIG_PATH unset users.$USERNAME
  kubectl config --kubeconfig=$KUBECONFIG_PATH unset clusters.kubernetes-cluster

  # Check if any context, user, or cluster remains and delete the kubeconfig file if empty
  if kubectl config view --kubeconfig=$KUBECONFIG_PATH -o json | jq -e '.contexts | length == 0 and .users | length == 0 and .clusters | length == 0' > /dev/null; then
    echo "Kubeconfig file is empty, deleting it..."
    rm $KUBECONFIG_PATH
  else
    # Set a default context if possible
    DEFAULT_CONTEXT=$(kubectl config get-contexts -o name --kubeconfig=$KUBECONFIG_PATH | head -n 1)
    if [ -n "$DEFAULT_CONTEXT" ]; then
      kubectl config use-context $DEFAULT_CONTEXT --kubeconfig=$KUBECONFIG_PATH
      echo "Switched to context: $DEFAULT_CONTEXT"
    else
      echo "No other context available. You may need to set a new context manually."
    fi
    echo "Kubeconfig file is not empty. Only specified context, user, and cluster have been removed."
  fi
else
  echo "Kubeconfig file $KUBECONFIG_PATH does not exist, skipping removal."
fi

# Check if the destination directory exists
if [ -d "$DEST_DIR" ]; then
  echo "Removing certificates in $DEST_DIR..."

  # Remove the generated private key, client certificate, and CA certificate
  rm -f $DEST_DIR/client.key
  rm -f $DEST_DIR/client.crt
  rm -f $DEST_DIR/ca.crt

  # Check if the directory is empty and remove it if it is
  if [ -z "$(ls -A $DEST_DIR)" ]; then
    echo "Directory $DEST_DIR is empty, deleting it..."
    rmdir $DEST_DIR
  else
    echo "Directory $DEST_DIR is not empty, only specified files have been removed."
  fi
else
  echo "Directory $DEST_DIR does not exist, skipping removal."
fi

echo "Uninstallation complete."
