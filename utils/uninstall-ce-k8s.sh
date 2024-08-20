#!/bin/bash

# Uninstall script for removing resources created by the CE setup script

# Delete the YAML configuration applied
if [ -f "ce-k8s.yaml" ]; then
  kubectl delete -f ce-k8s.yaml
  echo "Deleted resources from ce-k8s.yaml."
else
  echo "ce-k8s.yaml not found. Skipping deletion of resources."
fi

# Delete PersistentVolumes
kubectl delete pv pv-etcvpm pv-varvpm pv-data pv-etcd-0
echo "Deleted PersistentVolumes: pv-etcvpm, pv-varvpm, pv-data, pv-etcd-0."

# Optional: Clean up any remaining artifacts
rm -f ce-k8s.yaml
echo "Removed ce-k8s.yaml file."

# Verify that all resources have been deleted
echo "Verifying that all resources have been deleted..."
kubectl get all -n ves-system --ignore-not-found
kubectl get pv --ignore-not-found
kubectl get pvc --ignore-not-found


# Function to remove a directory if it exists
remove_dir_if_exists() {
    local dir=$1
    if [ -d "$dir" ]; then
        echo "Removing directory: $dir"
        rm -rf "$dir"
        echo "Directory $dir removed."
    else
        echo "Directory $dir does not exist. Skipping."
    fi
}

# Directories to be removed
remove_dir_if_exists "/mnt/data/etcvpm"
remove_dir_if_exists "/mnt/data/varvpm"
remove_dir_if_exists "/mnt/data/data"
remove_dir_if_exists "/mnt/data/etcd-0"

echo "All specified directories have been processed."

echo "Uninstallation completed."
