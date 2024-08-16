#!/bin/bash

# Confirm uninstallation
read -p "Are you sure you want to uninstall the resources in the 'ves-system' namespace and remove the 'local-storage' StorageClass? (y/n): " confirm
if [[ $confirm != "y" ]]; then
  echo "Uninstallation aborted."
  exit 1
fi

# Delete the yaml file
echo "Deleting ce-k8s.yaml file."
rm -rf $HOME/ce-k8s.yaml

# Delete the resources in the ves-system namespace
echo "Deleting resources in the 'ves-system' namespace..."

kubectl delete namespace ves-system

# Delete the StorageClass
echo "Deleting the 'local-storage' StorageClass..."

kubectl delete storageclass local-storage

# Delete the PersistentVolumeClaims
echo "Deleting PersistentVolumeClaims in the 'ves-system' namespace..."

kubectl delete pvc -n ves-system --all

# Delete PersistentVolumes that might have been created manually
echo "Deleting any manually created PersistentVolumes..."

kubectl delete pv $(kubectl get pv -o name | grep 'pv-etcvpm\|pv-varvpm\|pv-data')

# Confirm the deletion of all resources
echo "Verifying that all resources have been deleted..."

kubectl get all -n ves-system

kubectl get storageclass

kubectl get pv

echo "Uninstallation completed."
