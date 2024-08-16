#!/bin/bash

# User-defined variables
HOSTNAME="worker-node"
read -p "Enter the IP address for this node: " IP_ADDRESS1

read -p "Enter the IP address for the master node: " IP_ADDRESS2

# Set Host File
echo "$IP_ADDRESS1 worker-node" | sudo tee -a /etc/hosts 
echo "$IP_ADDRESS2 master-node" | sudo tee -a /etc/hosts 

# Update and install Docker
sudo apt update
sudo apt install docker.io -y

# Enable and check Docker service status
sudo systemctl enable docker

# Add Kubernetes APT repository and key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list and install Kubernetes components
sudo apt update
sudo apt install kubeadm kubelet kubectl -y

# Prevent these packages from being automatically updated
sudo apt-mark hold kubeadm kubelet kubectl

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load necessary kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Set hostname
sudo hostnamectl set-hostname $HOSTNAME

# Update kubelet configuration
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"' | sudo tee /etc/default/kubelet

# Reload systemd and restart kubelet
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# Update Docker daemon configuration
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Reload systemd and restart Docker
sudo systemctl daemon-reload && sudo systemctl restart docker

# Disable AppArmor (optional, depends on your setup)
sudo systemctl stop apparmor
sudo systemctl disable apparmor
sudo systemctl restart containerd.service

# Update kubelet systemd service configuration
echo 'Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"' | sudo tee -a /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

# Reload systemd and restart kubelet
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# Command to run on master node to retrieve join token
echo "To retrieve the join token, on the master k8s node run: kubeadm token create --print-join-command"

# Prompt for kubeadm join command (you can replace this with an actual join command if you have the token and control-plane IP)
read -p "Enter the kubeadm join command: " sudo JOIN_COMMAND
$JOIN_COMMAND


