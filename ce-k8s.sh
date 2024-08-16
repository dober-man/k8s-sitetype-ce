#!/bin/bash

# Prompt user for input
read -p "Enter an arbitrary Cluster Name for your CE: " cluster_name
read -p "Enter the Latitude: " latitude
read -p "Enter the Longitude: " longitude
read -p "Enter the Site Token (from XC Console): " site_token
read -p "Enter the number of replicas (1 for single-node, 3 for multi-node): " replicas

# Confirm inputs
echo "Cluster Name: $cluster_name"
echo "Latitude: $latitude"
echo "Longitude: $longitude"
echo "Site Token: $site_token"
echo "Replicas: $replicas"

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
EOF

echo "PersistentVolumes have been created."

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
kind: StatefulSet 
metadata:
  name: vp-manager
  namespace: ves-system
spec:
  replicas: $replicas
  selector:
    matchLabels:
      name: vpm
  serviceName: "vp-manager"
  template:
    metadata:
      labels:
        name: vpm
        statefulset: vp-manager
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
      terminationGracePeriodSeconds: 1 
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
  volumeClaimTemplates:
  - metadata:
      name: etcvpm
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
  - metadata:
      name: varvpm
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
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
# CHANGE ME
# PLEASE UNCOMMENT TO ENABLE SITE TO SITE ACCESS VIA NODEPORT
#---
#apiVersion: v1
#kind: Service
#metadata:
#  name: ver-nodeport-ver-0
#  namespace: ves-system
#  labels:
#    app: ver
#spec:
#  type: NodePort
#  ports:
#    - name: "ver-ike"
#      protocol: UDP
#      port: 4500
#      targetPort: 4500
#      nodePort: 30500
#  selector:
#    statefulset.kubernetes.io/pod-name: ver-0
#---
#apiVersion: v1
#kind: Service
#metadata:
#  name: ver-nodeport-ver-1
#  namespace: ves-system
#  labels:
#    app: ver
#spec:
#  type: NodePort
#  ports:
#    - name: "ver-ike"
#      protocol: UDP
#      port: 4500
#      targetPort: 4500
#      nodePort: 30501
#  selector:
#    statefulset.kubernetes.io/pod-name: ver-1
#---
#apiVersion: v1
#kind: Service
#metadata:
#  name: ver-nodeport-ver-2
#  namespace: ves-system
#  labels:
#    app: ver
#spec:
#  type: NodePort
#  ports:
#    - name: "ver-ike"
#      protocol: UDP
#      port: 4500
#      targetPort: 4500
#      nodePort: 30502
#  selector:
#    statefulset.kubernetes.io/pod-name: ver-2

EOF

echo "YAML configuration file 'ce-k8s.yaml' has been generated."

kubectl apply -f ce-k8s.yaml

echo "Verify that the pod with the vp-manager-0 under the NAME column indicates that the Site pod was created."

echo "Run: kubectl get pods -n ves-system -o=wide"
