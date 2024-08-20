#!/bin/bash

set -e  # Exit immediately if any command fails

# Function to delete resources if they exist
delete_resource_if_exists() {
  resource_type=$1
  resource_name=$2
  namespace=$3

  if kubectl get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null; then
    echo "Deleting $resource_type $resource_name in namespace $namespace..."
    kubectl delete "$resource_type" "$resource_name" -n "$namespace"
  else
    echo "$resource_type $resource_name in namespace $namespace does not exist."
  fi
}

# Function to delete a cluster-wide resource
delete_cluster_resource_if_exists() {
  resource_type=$1
  resource_name=$2

  if kubectl get "$resource_type" "$resource_name" &>/dev/null; then
    echo "Deleting cluster-wide $resource_type $resource_name..."
    kubectl delete "$resource_type" "$resource_name"
  else
    echo "Cluster-wide $resource_type $resource_name does not exist."
  fi
}

# Delete the StatefulSet
delete_resource_if_exists statefulset vp-manager ves-system

# Delete the DaemonSet
delete_resource_if_exists daemonset volterra-ce-init ves-system

# Delete the ConfigMap
delete_resource_if_exists configmap vpm-cfg ves-system

# Delete the Service
delete_resource_if_exists service vpm ves-system

# Delete the ServiceAccounts
delete_resource_if_exists serviceaccount volterra-sa ves-system
delete_resource_if_exists serviceaccount vpm-sa ves-system

# Delete the RoleBindings
delete_resource_if_exists rolebinding volterra-admin-role-binding ves-system
delete_resource_if_exists rolebinding vpm-role-binding ves-system

# Delete the Roles
delete_resource_if_exists role volterra-admin-role ves-system
delete_resource_if_exists role vpm-role ves-system

# Delete the ClusterRoleBindings
delete_cluster_resource_if_exists clusterrolebinding vpm-sa
delete_cluster_resource_if_exists clusterrolebinding ver

# Delete the ClusterRoles
delete_cluster_resource_if_exists clusterrole vpm-cluster-role

# Delete the namespace (this will remove all remaining resources in the namespace)
if kubectl get namespace ves-system &>/dev/null; then
  echo "Deleting namespace ves-system..."
  kubectl delete namespace ves-system
else
  echo "Namespace ves-system does not exist."
fi

# Delete the StorageClass
delete_cluster_resource_if_exists storageclass local-path

# Uninstall the local-path provisioner
echo "Uninstalling local-path provisioner..."
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

echo "Uninstallation complete."
