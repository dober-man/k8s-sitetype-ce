#!/bin/bash

set -e  # Exit immediately if any command fails

# Function to check if a directory exists and create it if it doesn't
create_dir_if_not_exists() {
  if [ ! -d "$1" ]; then
    echo "Directory $1 does not exist. Creating it..."
    mkdir -p "$1"
  fi
}

# Function to validate if input is a number
validate_number() {
  if ! [[ $1 =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: $2 must be a valid number."
    exit 1
  fi
}

# Prompt user for input
read -p "Enter an arbitrary Cluster Name for your CE: " cluster_name
read -p "Enter the Latitude: " latitude
read -p "Enter the Longitude: " longitude
read -p "Enter the Site Token (from XC Console): " site_token
read -p "Enter the number of replicas (1 for single-node, 3 for multi-node): " replicas


# Validate inputs
validate_number "$latitude" "Latitude"
validate_number "$longitude" "Longitude"

if [[ "$replicas" != "1" && "$replicas" != "3" ]]; then
  echo "Error: Number of replicas must be 1 or 3."
  exit 1
fi

# Confirm inputs
echo "Cluster Name: $cluster_name"
echo "Latitude: $latitude"
echo "Longitude: $longitude"
echo "Site Token: $site_token"
echo "Replicas: $replicas"

# Create namespace first
kubectl create namespace ves-system || true  # If the namespace exists, continue without error


# Ensure required directories exist for PersistentVolumes
create_dir_if_not_exists "/mnt/data/etcvpm"
create_dir_if_not_exists "/mnt/data/varvpm"
create_dir_if_not_exists "/mnt/data/data"
create_dir_if_not_exists "/mnt/data/etcd-0"

# Create PersistentVolumes
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-etcvpm
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data/etcvpm
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-varvpm
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data/varvpm
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data/data
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-etcd-0
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data/etcd-0
  persistentVolumeReclaimPolicy: Retain
EOF

echo "PersistentVolumes have been created."

# Create PersistentVolumeClaims
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etcvpm
  namespace: ves-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: pv-etcvpm
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: varvpm
  namespace: ves-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: pv-varvpm
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: ves-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: pv-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etcd-0
  namespace: ves-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: pv-etcd-0
EOF

echo "PersistentVolumeClaims have been created."

# Generate the YAML configuration with user inputs
cat <<EOF > ce-k8s.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ves-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: volterra-sa
  namespace: ves-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: volterra-admin-role
  namespace: ves-system
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: volterra-admin-role-binding
  namespace: ves-system
subjects:
- kind: ServiceAccount
  name: volterra-sa
  apiGroup: ""
  namespace: ves-system
roleRef:
  kind: Role
  name: volterra-admin-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: volterra-ce-init 
  namespace: ves-system
spec:
  selector:
    matchLabels:
      name: volterra-ce-init
  template:
    metadata:
      labels:
        name: volterra-ce-init 
    spec:
      hostNetwork: true
      hostPID: true
      serviceAccountName: volterra-sa
      containers:
      - name: volterra-ce-init
        image: gcr.io/volterraio/volterra-ce-init
        volumeMounts:
        - name: hostroot 
          mountPath: /host
        securityContext:
          privileged: true
      volumes:
      - name: hostroot
        hostPath:
          path: /
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vpm-sa
  namespace: ves-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vpm-role
  namespace: ves-system
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: vpm-cluster-role
  namespace: ves-system
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vpm-role-binding
  namespace: ves-system
subjects:
- kind: ServiceAccount
  name: vpm-sa
  apiGroup: ""
  namespace: ves-system
roleRef:
  kind: Role
  name: vpm-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vpm-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: vpm-cluster-role
subjects:
- kind: ServiceAccount
  name: vpm-sa
  namespace: ves-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ver
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ver
  namespace: ves-system
---
apiVersion: v1 
kind: ConfigMap 
metadata:
  name: vpm-cfg
  namespace: ves-system
data: 
 config.yaml: | 
  Vpm:
    ClusterName: $cluster_name
    ClusterType: ce
    Config: /etc/vpm/config.yaml
    DisableModules: ["recruiter"]
    Latitude: $latitude
    Longitude: $longitude
    MauriceEndpoint: https://register.ves.volterra.io
    MauricePrivateEndpoint: https://register-tls.ves.volterra.io
    PrivateNIC: eth0
    SkipStages: ["osSetup", "etcd", "kubelet", "master", "voucher", "workload", "controlWorkload", "csi"]
    Token: $site_token
    CertifiedHardware: k8s-minikube-voltmesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vp-manager
  namespace: ves-system
spec:
  replicas: $replicas
  selector:
    matchLabels:
      name: vpm
  template:
    metadata:
      labels:
        name: vpm
    spec:
      serviceAccountName: vpm-sa
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: name
                operator: In
                values:
                - vpm
            topologyKey: kubernetes.io/hostname
      initContainers:
      - name : vpm-init-config
        image: busybox
        volumeMounts:
        - name: etcvpm
          mountPath: /etc/vpm
        - name: vpmconfigmap
          mountPath: /tmp/config.yaml
          subPath: config.yaml
        command:
        - "/bin/sh"
        - "-c"
        - "cp /tmp/config.yaml /etc/vpm"
      containers:
      - name: vp-manager 
        image: gcr.io/volterraio/vpm
        imagePullPolicy: Always
        volumeMounts:
        - name: etcvpm
          mountPath: /etc/vpm
        - name: varvpm
          mountPath: /var/lib/vpm
        - name: podinfo
          mountPath: /etc/podinfo
        - name: data
          mountPath: /data
        securityContext:
          privileged: true
      terminationGracePeriodSeconds: 30 
      volumes:
      - name: podinfo
        downwardAPI:
          items:
            - path: "labels"
              fieldRef:
                fieldPath: metadata.labels
      - name: vpmconfigmap
        configMap:
          name: vpm-cfg
      - name: etcvpm
        persistentVolumeClaim:
          claimName: etcvpm
      - name: varvpm
        persistentVolumeClaim:
          claimName: varvpm
      - name: data
        persistentVolumeClaim:
          claimName: data
---
apiVersion: v1
kind: Service
metadata:
  name: vpm
  namespace: ves-system
spec:
  type: NodePort
  selector:
    name: vpm
  ports:
  - protocol: TCP
    port: 65003
    targetPort: 65003
EOF

echo "YAML configuration file 'ce-k8s.yaml' has been generated."

# Apply the generated YAML configuration
if kubectl apply -f ce-k8s.yaml; then
  echo "Configuration applied successfully."
else
  echo "Error applying configuration."
  exit 1
fi

echo "Verify that the pod with the vp-manager-0 under the NAME column indicates that the Site pod was created."

echo "Run: watch kubectl get pods -n ves-system -o=wide"
